----------------------------------------------------------------------------------------------------
-- Module Initialization
----------------------------------------------------------------------------------------------------

local _M = {}

----------------------------------------------------------------------------------------------------
-- Local Constants
----------------------------------------------------------------------------------------------------

DirectoryPagination = '/list?sortType=created'
DirectoryParameters = '&offset='
DirectoryOffset     = 70

----------------------------------------------------------------------------------------------------
-- Event Functions
----------------------------------------------------------------------------------------------------

-- Get info and chapter list for current manga.
function _M.GetInfo()
  local rtitle = ''
  local x, v = nil
  local u = MaybeFillHost(MODULE.RootURL, URL)

  if not HTTP.GET(u) then return net_problem end

  x = CreateTXQuery(HTTP.Document)
  rtitle              = x.XPathString('//h1[@class="NAMES"]/span[@class="name"]')
  MANGAINFO.Title     = x.XPathString('//h1[@class="NAMES"]/span[@class="eng-name"]')
  MANGAINFO.CoverLink = x.XPathString('//div[@class="picture-fotorama"]/img/@src')
  MANGAINFO.Authors   = x.XPathStringAll('//p[@class="elementList"]/span[contains(@class, "elem_author")]/a[@class="person-link"]/text()|//p[@class="elementList"]/span[contains(@class, "elem_screenwriter")]/a[@class="person-link"]/text()')
  MANGAINFO.Artists   = x.XPathStringAll('//p[@class="elementList"]/span[contains(@class, "elem_illustrator")]/a[@class="person-link"]/text()')
  MANGAINFO.Genres    = x.XPathStringAll('//p[@class="elementList"]/span[contains(@class, "elem_genre")]/a/text()|//p[@class="elementList"]/span[contains(@class, "elem_tag")]/a/text()')
  MANGAINFO.Summary   = x.XPathString('//div[@class="manga-description"]')

  if MANGAINFO.Title == '' then MANGAINFO.Title = rtitle end
  if string.find(x.XPathString('//*[starts-with(@class,"subject-meta")]/*[starts-with(.,"Перевод:")]'), 'продолжается', 1, true) then MANGAINFO.Status = 1 else MANGAINFO.Status = 0 end

  v = x.XPath('//table[@class="table table-hover"]/tbody/tr/td/a')
  for i = 1, v.Count do
    MANGAINFO.ChapterLinks.Add(v.Get(i).GetAttribute('href'))
    MANGAINFO.ChapterNames.Add(v.Get(i).ToString():gsub(rtitle, ''))
  end
  MANGAINFO.ChapterLinks.Reverse(); MANGAINFO.ChapterNames.Reverse()

  return no_error
end

-- Get the page count of the manga list of the current website.
function _M.GetDirectoryPageNumber()
  local u = MODULE.RootURL .. DirectoryPagination

  if not HTTP.GET(u) then return net_problem end

  PAGENUMBER = tonumber(CreateTXQuery(HTTP.Document).XPathString('(//span[@class="pagination"])[last()]/a[@class="step"][last()]')) or 1

  return no_error
end

-- Get LINKS and NAMES from the manga list of the current website.
function _M.GetNameAndLink()
  local v, x = nil
  local u = MODULE.RootURL .. DirectoryPagination

  if URL ~= '0' then u = u .. DirectoryParameters .. (DirectoryOffset * tonumber(URL)) end

  if not HTTP.GET(u) then return net_problem end

  x = CreateTXQuery(HTTP.Document)
  x.XPathHREFAll('//div[@class="tiles row"]//div[@class="desc"]/h3/a', LINKS, NAMES)

  return no_error
end

-- Get the page count for the current chapter.
function _M.GetPageNumber()
  local json, x = nil
  local u = MaybeFillHost(MODULE.RootURL, URL)

  if string.find(URL, 'mtr=1', 1, true) == nil then u = u .. '?mtr=1' end

  if not HTTP.GET(u) then return net_problem end

  x = CreateTXQuery(HTTP.Document)
  json = GetBetween('[[', ', 0, ', Trim(GetBetween('rm_h.init(', 'false);', x.XPathString('//script[@type="text/javascript" and contains(., "rm_h.init")]'))))
  json = json:gsub('%],%[', ';'):gsub('\'', ''):gsub('"', ''):gsub(']]', ';')
  for i in json:gmatch('(.-);') do
    i1, i2 = i:match('(.-),.-,(.-),.-,.-')
    TASK.PageLinks.Add(i1 .. i2)
  end

  return no_error
end

----------------------------------------------------------------------------------------------------
-- Module After-Initialization
----------------------------------------------------------------------------------------------------

return _M
