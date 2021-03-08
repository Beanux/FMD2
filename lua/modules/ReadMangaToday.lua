local dirurls = 'abcdefghijklmnopqrstuvwxyz'

function GetDirectoryPageNumber()
	PAGENUMBER = dirurls:len()
	return no_error
end

function GetNameAndLink()
	local i = (tonumber(URL) or 0) + 1
	if HTTP.GET(MODULE.RootURL..'/manga-list/'..dirurls:sub(i, i)) then
			CreateTXQuery(HTTP.Document).XPathHREFAll('//*[@class="manga-item"]//a', LINKS, NAMES)
		return no_error
	else
		return net_problem
	end
end

function GetInfo()
	MANGAINFO.URL = MaybeFillHost(MODULE.RootURL, URL)
	if HTTP.GET(MANGAINFO.URL) then
		local x = CreateTXQuery(HTTP.Document)

		MANGAINFO.CoverLink = x.XPathString('//*[@class="panel-body"]//img/@src')
		MANGAINFO.Title     = x.XPathString('//h1')
		MANGAINFO.Authors   = x.XPathString('//li[.="Author"]/preceding-sibling::li')
		MANGAINFO.Artists   = x.XPathString('//li[.="Artist"]/preceding-sibling::li')
		MANGAINFO.Genres    = x.XPathString('//*[@class="dl-horizontal"]/dt[starts-with(.,"Categories")]/following-sibling::dd[1]/string-join(*,", ")')
		MANGAINFO.Summary   = x.XPathString('//*[contains(@class,"movie-detail")]')
		MANGAINFO.Status    = MangaInfoStatusIfPos(x.XPathString('//*[@class="dl-horizontal"]/dt[starts-with(.,"Status")]/following-sibling::dd[1]'))

		local v; for v in x.XPath('//ul[@class="chp_lst"]/li/a').Get() do
			MANGAINFO.ChapterLinks.Add(v.GetAttribute('href'))
			MANGAINFO.ChapterNames.Add(x.XPathString('span[1]', v))
		end
		MANGAINFO.ChapterLinks.Reverse(); MANGAINFO.ChapterNames.Reverse()
		return no_error
	else
		return net_problem
	end
end

function GetPageNumber()
	if HTTP.GET(MaybeFillHost(MODULE.RootURL, URL)) then
		local x = CreateTXQuery(HTTP.Document)
		x.ParseHTML(GetBetween('var images = ', ';', x.XPathString('//script[contains(., "var images")]')))
		local v for v in x.XPath('json(*)().url').Get() do
			TASK.PageLinks.Add(v.ToString())
		end
		return true
	else
		return false
	end
end

function Init()
	local m = NewWebsiteModule()
	m.ID                         = '89eb675e8eb049c485a5a475f8f5c0c9'
	m.Name                       = 'ReadMangaToday'
	m.RootURL                    = 'https://www.readmng.com'
	m.Category                   = 'English'
	m.OnGetDirectoryPageNumber   = 'GetDirectoryPageNumber'
	m.OnGetNameAndLink           = 'GetNameAndLink'
	m.OnGetInfo                  = 'GetInfo'
	m.OnGetPageNumber            = 'GetPageNumber'
end
