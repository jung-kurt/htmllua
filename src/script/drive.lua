local gumbo = require "gumbo"

drive = {}

local tinsert = table.insert
local tconcat = table.concat
local printf = util.printf

-- Retreive a web resource by URL. The downloaded file and its associated
-- response headers (extension '.hdr') will be cached in the specified cache
-- directory. An attempt to download the resource will be made without checking
-- the cache first if download is true. The name of the cached file is returned
-- on success, (nil, err) otherwise.
local function get(url, cache, download)
  printf('retrieving %s', util.shortstr(url, 32, 32))
  local hdrfilestr, cmd, filestr, html, ok, err
  filestr = util.pathjoin(cache, util.zencode(url))
  if download or (lfs.attributes(filestr, 'mode') ~= 'file') then
    hdrfilestr = filestr .. '.hdr'
    ok = util.execute('curl --dump-header "%s" --silent --output "%s" "%s"', hdrfilestr, filestr, url)
    if ok then
      printf(' [network]\n')
    else
      err = 'error retrieving content via curl\n'
    end
  else
    printf(' [file]\n')
  end
  return util.ret(filestr, err)
end

-- Remove gumbo elements by tag (for example, 'body', 'div', etc). One or more
-- tags can be specified after the document argument.
local function gumboRemoveByTag(doc, ...)
  local taglist = { ... }
  for _, tag in ipairs(taglist) do
    local ellist = doc:getElementsByTagName(tag)
    for j, el in ipairs(ellist) do
      el:remove()
    end
  end
end

-- Remove gumbo elements by ID. One or more IDs can be specified after the
-- document argument.
local function gumboRemoveById(doc, ...)
  local idlist = { ... }
  for _, id in ipairs(idlist) do
    local el = doc:getElementById(id)
    if el then
      el:remove()
    end
  end
end

-- Return a table of attribute keys and values associated with the specified
-- element
local function gumboAttrs(el)
  local rec = {}
  if el.attributes then
    for j, v in ipairs(el.attributes) do
      if v.name then
        rec[v.name] = v.value
      end
    end
  end
  return rec
end

-- Return the built-up string in the line buffer. Clear the buffer before
-- returning. If the string is of the form '[key]: value' then place the
-- key/value pair into the reference map.
local function bufstr(rec)
  local str = tconcat(rec.buf)
  rec.buf = {}
  str = str:gsub(' +$', '')
  local key, val = string.match(str, '^%[(.-)%]%s*%:%s*(.-)$')
  if key then
    rec.refmap[key] = val
  end
  return str
end

-- Append the specified string into the output table. Do not begin the table
-- with a blank line and do not follow a blank line with another.
local function outappend(rec, str)
  local top = #rec.outstk == 0 and '' or rec.outstk[#rec.outstk]
  if top ~= '' or str ~= '' then
    tinsert(rec.outstk, str)
  end
end

-- Append the current buffer to the output table. If blankafter is true, follow
-- this line with a blank line.
local function bufclose(rec, blankafter)
  outappend(rec, bufstr(rec))
  if blankafter then
    outappend(rec, '')
  end
end

-- Close either an ordered or unordered list item. Convert each colon between
-- the list bullet (either a star or digit) to a span of four spaces, the
-- amount of indentation Markdown specifies to nest a sublist. Google Docs
-- encodes only the base level of ol and ul lists and renders sublists with
-- class styles. The colon notation is a way for this script to construct true
-- nested lists.
local function bufcloselistitem(rec)
  local colon, lead, str
  str = bufstr(rec)
  lead = rec.liststk[#rec.liststk];
  colon, str = str:match('^([%s%:]*)(.*)$')
  colon = colon:gsub('%s', '') -- leave only colons
  str = string.rep('    ', #colon) .. lead .. str
  outappend(rec, str)
end

-- Close an image reference. Make sure the image is cached. It will be
-- downloaded if it is not already cached.
local function bufcloseimage(rec, imgel)
  local attr = gumboAttrs(imgel)
  local style = attr.style or ''
  local title = attr.title or ''
  -- Google Drive embeds extraneous garbage into contents block; skip at least
  -- one kind here
  if title ~= 'horizontal line' then
    if attr.src then
      -- printf('image [%s]\n', filestr)
      title = util.replace(title, '"', '\\"')
      local alt = attr.alt or ''
      alt = util.replace(alt, '[', '\\[', ']', '\\]')
      alt = '' -- tmp
      local str = string.format('![%s](%s "%s")', alt, attr.src, title)
      outappend(rec, str)
      outappend(rec, '')
    end
  end
  rec.buf = {}
end

-- Recursively traverse the document tree. For each Markdown output line (for
-- example, header, paragraph, list item, etc), build up a buffer and perform
-- various transforms. Only a select few of the input tags are recognized; the
-- rest are ignored.
local function pagedescend(nodes, rec, ins)
  for j, k in ipairs(nodes) do
    local tag = k.localName
    -- print(tag or k.data, #rec.outstk)
    if tag then
      if tag == 'h1' then
        ins('# ')
      elseif tag == 'h2' then
        ins('## ')
      elseif tag == 'h3' then
        ins('### ')
      elseif tag == 'h4' then
        ins('#### ')
      elseif tag == 'h5' then
        ins('##### ')
      elseif tag == 'h6' then
        ins('###### ')
      elseif tag == 'img' then
      elseif tag == 'ul' then
        tinsert(rec.liststk, '* ')
      elseif tag == 'ol' then
        tinsert(rec.liststk, '1. ')
      elseif tag == 'hr' then
        ins('***')
      end
      table.insert(rec.tagstk, tag)
      pagedescend(k.childNodes, rec, ins)
      table.remove(rec.tagstk)
      if tag == 'p' or tag == 'h1' or tag == 'h2' or tag == 'h3' or tag == 'h4' or tag == 'h5' or tag == 'h6' then
        bufclose(rec, true)
      elseif tag == 'img' then
        bufcloseimage(rec, k)
      elseif  tag == 'ul' or tag == 'ol' then
        table.remove(rec.liststk)
        bufclose(rec)
      elseif tag == 'li' then
        bufcloselistitem(rec)
      elseif tag == 'hr' then
        bufclose(rec, true)
      end
    elseif k.data then -- text node (no tag or attributes)
      ins(k.data)
    end
  end
end

-- Add a key/value pair to linkmap that points from name of hardlink to cached
-- image file.
local function linkname(src, title, cache, linkmap)
  local filename, filestr, hdr, err, link
  filestr, err = get(src, cache)
  if filestr then
    hdr, err = util.fileread(filestr .. '.hdr')
    if hdr then
      filename = string.match(hdr, 'filename="(.-)"')
      if filename then
        local base, ext = string.match(filename, '^(.*)(%..-)$')
        if base then
          if title == '' then
            link = filename
          else
            link = util.titletoname(title) .. ext
          end
          while linkmap[link] do
            link = 'a' .. link -- make linkname unique for this page
          end
          linkmap[link] = filestr
        else
          err = 'error extracting image extension from filename'
        end
      else
        err = 'error extracting filename from response header'
      end
    end
  end
  return util.ret(link, err)
end

-- Generate a figure block from a simple HTML image block.
local function figure(figureStr, cache, linkmap)
  local ret = {}
  local imgStr, tailStr = figureStr:match('^([^>]*)%>(.*)$')
  if imgStr then
    local src = imgStr:match('src="([^"]*)')
    if src then
      local lead
      local alt = imgStr:match(' alt="(.-)"') or ''
      local title = imgStr:match(' title="(.-)"') or ''
      lead, title = string.match(title, '^([ %*]*)(.*)$')
      local pos = string.find(lead, '*', 1, true)
      local shadow = pos and ' class="shadow"' or ''
      local width = imgStr:match(' width="%d+"') or ''
      local height = imgStr:match(' height="%d+"') or ''
      local anchor = tailStr:match('%((.-)%)')
      local shim = ''
      ret[#ret + 1] = '<figure>'
      if anchor then
        ret[#ret + 1] = string.format('  <a href="%s" rel="noopener" target="_blank">', anchor)
        shim = '  '
      end
      local link = linkname(src, title, cache, linkmap)
      -- create hardlink in page directory to cached image
      ret[#ret + 1] = string.format('  %s<img src="%s" alt="%s"%s%s%s />', shim, link, alt, width, height, shadow)
      -- ret[#ret + 1] = string.format('  %s<img src="%s" alt="%s"%s%s%s />', shim, src, alt, width, height, shadow)
      if anchor then
        ret[#ret + 1] = '  </a>'
      end
      if #title > 0 then
        ret[#ret + 1] = string.format('  <figcaption>%s</figcaption>', title)
      end
      ret[#ret + 1] = '</figure>'
    end
  end
  return table.concat(ret, '\n')
end

-- Perform various substitutions on the HTML that the discount library
-- generates. Make the following conversions:
-- <p><img ...></p> to a figure block.
-- <p>:foo:</p> to <div class="foo">
-- <p>::</p> to </div>
-- <p>.bar.Oh what a tangled web</p> to <p class="bar">Oh what a tangled web</p>
--
-- These are lexical conversions rather than semantic. Consequently they are
-- fragile and can lead to non-conformant HTML
local function postprocess(html, cache, linkmap)
  return (html:gsub('<p><img(.-)</p>', function(s) return figure(s, cache, linkmap) end):
    gsub('<p>%:(%a%w*)%:%s*</p>', '<div class="%1">'):
    gsub('<p>%:%:%s*</p>', '</div>'):
    gsub('<p>%.(%a%w*)%.%s*(.-)</p>', '<p class="%1">%2</p>'))
end

-- Clean the rat's nest of HTML that is delivered from Google and augment it
-- with certain extensions. It does this by generating a Markdown intermediate
-- file and then converting this back to HTML. Curly quotes and non-breakable
-- spaces are replaced with ASCII replacements.
local function process(tree, cache, site)
  -- rec.liststk is a stack of list item bullets ('* ' for unordered, '1. ' for
  -- ordered). A simple boolean would suffice because Drive does not generate
  -- semantic nested lists. Instead it renders sublists with display styles. A
  -- stack may be needed later if this script attempts to parse styles.
  local rec = {
    tagstk = {},
    outstk = {},
    buf = {},
    liststk = {},
    refmap = {},
    cache = cache,
    site = site,
  }
  local ret = {}
  local function ins(str)
    -- For consistency, make sure markdown sees only ASCII quotes and ordinary spaces
    str = util.replace(str, '“', '"', '”', '"', "‘", "'", "’", "'", ' ', ' ')
    tinsert(rec.buf, str)
  end
  pagedescend(tree, rec, ins)
  ret.markdown = tconcat(rec.outstk, '\n')
  local htmlrec, err = discount.compile(ret.markdown)
  if err == nil then
    ret.refmap = rec.refmap
    ret.linkmap = {}
    ret.html = postprocess(htmlrec.body, cache, ret.linkmap)
    return ret
  end
  return nil, err
end

-- Convert HTML from a published-to-web document on Google Drive. Return a
-- table with fields html (semantically clean HTML), markdown, and refmap (a
-- map of the references in markdown document), or nil followed by an error
-- message.
function drive.convert(filestr, cache, site)
  local ret, doc, err
  doc, err = gumbo.parseFile(filestr)
  if doc then
    -- Collect title before head block is removed
    local title = doc.title or ''
    gumboRemoveByTag(doc, 'script', 'head', 'style')
    gumboRemoveById(doc, 'header', 'footer')
    ret, err = process(doc.childNodes, cache, site)
    if ret then
      if not ret.refmap.title then
        ret.refmap.title = title
      end
    end
  end
  return util.ret(ret, err)
end

-- Display a tagged document node with some of its attributes or else the
-- node's text value. This is a development function only.
local function shownode(el, indent)
  local attr = gumboAttrs(el)
  local name = el.localName
  if name then
    name = '<' .. name
    if attr.id then
      name = name .. ' id="' .. attr.id .. '"'
    end
    if attr.title then
      name = name .. ' title="' .. attr.title .. '"'
    end
    if attr.src then
      name = name .. ' src="' .. util.shortstr(attr.src, 32) .. '"'
    end
    name = name .. '>'
  else
    name = util.shortstr(el.data or '', 32)
  end
  printf('%s%s\n', indent, name)
end

-- Traverse the contents page to build up the list of website page links.
local function contentsdescend(nodes, rec, ins, indent)
  for j, k in ipairs(nodes) do
    local tag = k.localName
    -- shownode(k, indent)
    if tag then
      -- print('open ' .. tag)
      if tag == 'td' then
        rec.td = rec.td + 1
      end
      contentsdescend(k.childNodes, rec, ins, indent .. '  ')
      if tag == 'tr' then
        rec.td = 0
      end
      -- print('close ' .. tag)
    elseif k.data then -- text node (no tag or attributes)
      if rec.td == 2 then
        ins(k.data)
      end
      -- print('text ' .. rec.td .. ': ' .. k.data)
    end
  end
end

-- Parse the contents page as delivered from Google Docs.
local function parse(node)
  local list = {}
  local rec = {
    td = 0,
  }
  local function ins(str)
    table.insert(list, str)
  end
  contentsdescend(node, rec, ins, '')
  return list
end

-- Retrieve the list of website page links from the contents page on Google
-- Docs.
local function getlist(url, cache)
  local list, filestr, err, doc, markdown

  filestr, err = get(url, cache, true)
  if not err then
    doc, err = gumbo.parseFile(filestr)
    if not err then
      gumboRemoveByTag(doc, 'script', 'head', 'style')
      gumboRemoveById(doc, 'header', 'footer')
      list = parse(doc.childNodes)
    end
  end
  if not err then
    return list
  end
  return nil, err
end

-- Generate a website page. This involves downloading the Google Docs version
-- from its publish-to-web link or retrieving it from the file cache if it has
-- already been downloaded. A page directory is made based on the title of the
-- page. The page's intermediate markdown is stored in this directory as
-- main.md.
local function pagegen(url, cache, site)
  local rec, ok, html, markdown, filestr, err

  filestr, err = get(url, cache, true)
  if filestr then
    -- printf('Convert %s\n', filestr)
    rec, err = drive.convert(filestr, cache, site)
    if rec then
      rec.title = rec.refmap.title or '---'
      rec.name = util.titletoname(rec.title)
      if rec.title == 'Home' then
        rec.dir = site
        rec.toroot = ''
      else
        rec.dir = util.pathjoin(site, rec.name)
        rec.toroot = '../'
        if not util.mkdir(rec.dir) then
          err = 'error creating directory ' .. rec.dir
        end
      end
      if not err then
        ok, err = util.filewrite(rec.dir .. '/main.md', rec.markdown)
        for k, v in pairs(rec.linkmap) do
          local linkstr = util.pathjoin(rec.dir, k)
          -- printf('hardlink [%s] -> [%s]\n', linkstr, util.shortstr(v, 24, 24))
          lfs.link(v, linkstr)
        end
      end
    end
  end
  return util.ret(rec, err)
end

-- Write a finished web page to the page's directory in the website. This
-- involves generating the page content and then applying it a page template
-- with various textual substitutions.
local function pagewrite(rec, reclist, template)
  local path, str, mstr, ok, side, err, sidelist
  sidelist = {}
  for _, r in ipairs(reclist) do
    if rec.title == r.title then
      mstr = string.format('**%s**', rec.title)
    else
      if r.title == 'Home' then
        path = rec.toroot
      else
        path = rec.toroot .. r.name .. '/'
      end
      mstr = string.format('[%s](%sindex.html)', r.title, path)
    end
    sidelist[#sidelist + 1] = mstr
  end
  side, err = discount.compile(table.concat(sidelist, '\n\n'))
  if side then
    -- util.show(side)
    str = util.replace(template, '{TITLE}', rec.title, '{CSS}', rec.toroot .. 'index.css',
      '{FAVICON}', rec.toroot .. 'favicon.ico', '{MAIN}', rec.html, '{SIDE}', side.body,
      '{AUTHOR}', rec.refmap.author or 'Rose Heritage Committee')
    ok, err = util.filewrite(rec.dir .. '/index.html', str)
  end
  return err
end

-- Generate an entire website based on the pages that are listed in the Google
-- Docs contents page.
drive.websitegenerate = function(template, site, url, cache)
  local err
  if util.mkdir(site) then
    template, err = util.fileread(template)
    if template then
      local list
      list, err = getlist(url, cache)
      if list then
        local count = 0
        local reclist = {}
        local rec
        -- Initial conversion loop
        for _, str in ipairs(list) do
          if err == nil then
            if count < 1024 then
              rec, err = pagegen(str, cache, site)
              if rec then
                reclist[#reclist + 1] = rec
              end
              count = count + 1
            end
          end
        end
        -- Secondary contents and output loop
        for _, rec in ipairs(reclist) do
          if err == nil then
            err = pagewrite(rec, reclist, template)
          end
        end
      end
    end
  else
    err = 'error creating site directory'
  end
  return err
end
