function getinfo()
	MANGAINFO.URL=MaybeFillHost(MODULE.RootURL, URL)
	if HTTP.GET(MANGAINFO.URL) then
		x=CreateTXQuery(HTTP.Document)
		MANGAINFO.Title=x.XPathString('//h2[@class="tag-title"]/b')
		if MANGAINFO.Title == '' then MANGAINFO.Title = x.XPathString('//h3[@id="chapter-title"]/b') end
		MANGAINFO.CoverLink=MaybeFillHost(MODULE.RootURL,x.XPathString('//img[@class="thumbnail"]/@src'))
		MANGAINFO.Authors=x.XPathString('string-join(//a[contains(@href,"/authors/")],", ")')
		MANGAINFO.Genres=x.XPathStringAll('//*[@class="label" or @class="doujin_tags"]')
		MANGAINFO.Status=MangaInfoStatusIfPos(x.XPathString('//h2[@class="tag-title"]/small'))
		MANGAINFO.Summary=x.XPathString('//*[@class="description"]')
		x.XPathHREFAll('//dl[@class="chapter-list"]/dd/a[1]',MANGAINFO.ChapterLinks,MANGAINFO.ChapterNames)
		if MANGAINFO.ChapterLinks.Count == 0 then
			MANGAINFO.ChapterLinks.Add(URL)
			MANGAINFO.ChapterNames.Add(MANGAINFO.Title)
		end
		return no_error
	else
		return net_problem
	end
end

function getpagenumber()
	if HTTP.GET(MaybeFillHost(MODULE.RootURL,URL)) then
		CreateTXQuery(HTTP.Document).XPathStringAll('json(//script[contains(.,"var pages")]/substring-after(substring-before(.,";")," = "))()/concat("'..MODULE.RootURL..'",./image)',TASK.PageLinks)
		return true
	else
		return false
	end
	return true
end

local diruris={
		'/anthologies',
		'/doujins',
		'/issues',
		'/series'
		}

function getdirectorypagenumber()
	PAGENUMBER=#diruris
	return no_error
end

function getnameandlink()
	if HTTP.GET(MODULE.RootURL..diruris[tonumber(URL)+1]) then
		CreateTXQuery(HTTP.Document).XPathHREFAll('//dd/a',LINKS,NAMES)
		return no_error
	else
		return net_problem
	end
end

function Init()
	local m = NewWebsiteModule()
	m.ID                       = 'f5bc5d44e9f24a7a9afb40788acf20e3'
	m.Category                 = 'English-Scanlation'
	m.Name                     = 'DynastyScans'
	m.RootURL                  = 'https://dynasty-scans.com'
	m.OnGetInfo                = 'getinfo'
	m.OnGetPageNumber          = 'getpagenumber'
	m.OnGetDirectoryPageNumber = 'getdirectorypagenumber'
	m.OnGetNameAndLink         = 'getnameandlink'
end
