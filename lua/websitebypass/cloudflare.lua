local _m = {}

function _m.IUAMChallengeAnswer(self, body, url)
	local script = body:match('<script.->(.-)</script')

	if script == nil then
		LOGGER.SendError('WebsitBypass[clounflare]: IUAM challenge detected but failed to parse the javascript\r\n' .. url)
		return nil
	end

	local rooturl = url:match('(https?://[^/]+)') or ''

	local challenge = string.format([[
function btoa(s) {return Duktape.enc('base64', s);};
function atob(s) {return new TextDecoder().decode(Duktape.dec('base64', s));};

var $$e = {}, window = {}, document = {}, navigator = {}, location = { hash: "" },
    setTimeout = function (f, t) { $$e.timeout = t; f(); },
    setInterval = function (f, t) { f(); };

window.addEventListener = function () {};
window.navigator = { userAgent: '%s' };

navigator.cookieEnabled = true;

document.addEventListener = function (e, b, c) { b(); };
document.body = { appendChild: function () {} };

document.getElementById = function (id) {
    if (!$$e[id]) $$e[id] = { style: {}, action: "", submit: function () {} };
    return $$e[id];
};

document.createElement = function (tag) {
    return { firstChild: { href: "%s" }, setAttribute: function () {} };
};

String.prototype.big = function () { return "<big>" + this + "</big>"; };
String.prototype.small = function () { return "<small>" + this + "</small>"; };
String.prototype.bold = function () { return "<b>" + this + "</b>"; };
String.prototype.italics = function () { return "<i>" + this + "</i>"; };
String.prototype.fixed = function () { return "<tt>" + this + "</tt>"; };
String.prototype.strike = function () { return "<strike>" + this + "</strike>"; };
String.prototype.sub = function () { return "<sub>" + this + "</sub>"; };
String.prototype.sup = function () { return "<sup>" + this + "</sup>"; };

]], HTTP.UserAgent, rooturl)
	local i, v; for i, v in body:gmatch('<div%s*id="(%w+%d+)">(.-)</div') do
		if v:find('[]', 1, true) then
			challenge = challenge .. string.format('$$e["%s"] = { innerHTML: "%s" };\r\n', i, v:gsub('"', '\"'))
		end
	end
	challenge = challenge .. script .. '\r\nJSON.stringify($$e);'

	local answer, timeout = duktape.ExecJS(challenge)
	if (answer == nil) or (answer == 'NaN') or (answer == '') then
		-- LOGGER.SendError('WebsitBypass[clounflare]: IUAM challenge detected but failed to solve the javascript challenge\r\n' .. url .. '\r\n' .. body)
		-- LOGGER.SendError('WebsitBypass[clounflare]: IUAM challenge detected but failed to solve the javascript challenge\r\n' .. url .. '\r\n' .. challenge)
		LOGGER.SendError('WebsitBypass[clounflare]: IUAM challenge detected but failed to solve the javascript challenge\r\n' .. url)
	else
		answer = answer:match('"jschl%-answer":.-"value":"(.-)"')
		timeout = tonumber(answer:match('"timeout":(%d+)')) or 4000
	end

	return timeout, answer
end

function _m.sleepOrBreak(self, delay)
	local count = 0
	while count < delay do
		if HTTP.Terminated then break end
		count = count + 250
		sleep(250)
	end
end

function _m.solveIUAMChallenge(self, body, url)
	local timeout, answer = self:IUAMChallengeAnswer(body, url)
	if (answer == nil) or (answer == 'NaN') or (answer == '') then
		return 0
	end

	local form, challengeUUID = body:match('<form (.-="challenge%-form" action="(.-__cf_chl_jschl_tk__=%S+)"(.-)</form>)')
	if (form == nil) or (challengeUUID == nil) then
		LOGGER.SendError('WebsitBypass[clounflare]: IUAM challenge detected but failed to parse the form\r\n' .. url)
		return 0
	end
	challengeUUID = challengeUUID:gsub('&amp;', '&')

	-- cloudflare requires a delay
	self:sleepOrBreak(timeout)

	local payload = {}
	local k, n, v = '', '', ''
	for k in form:gmatch('\n%s*<input%s(.-name=".-)/>') do
		n = k:match('name="(.-)"')
		v = k:match('value="(.-)"') or ''
		payload[n] = v
	end

	local i = 0; for _ in pairs(payload) do i = i + 1 end
	if i == 0 then
		LOGGER.SendError('WebsitBypass[clounflare]: IUAM challenge detected but failed to parse the form payload\r\n' .. url)
		return 0
	end
	payload['jschl_answer'] = answer

	local rawdata = ''
	for k, v in pairs(payload) do
		rawdata = rawdata .. k .. '=' .. crypto.EncodeURLElement(payload[k]) .. '&'
	end
	rawdata = rawdata:gsub('&$', '')

	local rooturl = url:match('(https?://[^/]+)') or ''

	-- no need to redirect if it a success
	HTTP.FollowRedirection = false
	HTTP.Reset()
	HTTP.Headers.Values['Origin'] = ' ' .. rooturl
	HTTP.Headers.Values['Referer'] = ' ' .. url
	HTTP.MimeType = "application/x-www-form-urlencoded"
	HTTP.Document.WriteString(rawdata)
	HTTP.FollowRedirection = true

	HTTP.Request('POST', rooturl .. challengeUUID)
	local rbody = HTTP.Document.ToString()
	if rbody:find('^Access denied%. Your IP') then
		HTTP.ClearCookiesStorage()
		LOGGER.SendError('WebsitBypass[clounflare]: the server has BANNED your IP!\r\n' .. url .. '\r\n' .. rbody)
		return -1
	end
	if HTTP.Cookies.Values["cf_clearance"] ~= "" then
		return 1
	end

	return 0
end

function _m.solveWithPythonSelenium(self, url)
	local rooturl = url:match('(https?://[^/]+)') or ''

	local s = nil
	if tonumber(fmd.Revision) > 4985 then
		local sub = require("fmd.subprocess")
		_, s = sub.RunCommandHide(py_exe, py_cloudflare, rooturl, HTTP.UserAgent)
	else
		local exe = string.format('""%s" "%s" "%s" "%s""',py_exe,py_cloudflare,rooturl,HTTP.UserAgent)
		local py = io.popen(exe, "r")
		if py then
			s = py:read('*a')
			py:close()
		end
	end

	if (s==nil) or (s=="") then
		LOGGER.SendError('WebsitBypass[clounflare]: python selenium module failed or timeout\r\n' .. url)
		return -1
	end

	local json = require "utils.json"
	s = s:gsub("'",'"'):gsub("True","true"):gsub("False","false")
	local s = json.decode(s)
	local c
	local scookie
	local cookies = {}
	for _, c in ipairs(s) do
		cookie = {}
		table.insert(cookie,c["name"].."=" .. c["value"])
		c["name"]=nil
		c["value"]=nil
		if c["expiry"] then
			c["expires"]=os.date('!%a, %d %b %Y %H:%M:%H GMT',c["expiry"])
			c["expiry"]=nil
		end
		for k, v in pairs(c) do
			if type(v) == "boolean" then
				if v == true then table.insert(cookie,tostring(k)) end
			else
				table.insert(cookie,tostring(k).."="..tostring(v))
			end
		end
		table.insert(cookies,table.concat(cookie,"; "))
	end

	local scookies = table.concat(cookies,"\n")
	if scookies ~= "" then
		HTTP.AddServerCookies(scookies)
		return 2
	end
end

function _m.solveChallenge(self, url)
	local body = HTTP.Document.ToString()
	local rc = HTTP.ResultCode

	-- firewall blocked
	if (rc == 403) and body:find('<span class="cf%-error%-code">1020</span>') then
		LOGGER.SendError('WebsitBypass[clounflare]: Cloudflare has blocked this request (Code 1020 Detected)\r\n' .. url)
		return -1
	end
	-- reCapthca challenge
	if (rc == 403) and body:find('action="/.-__cf_chl_captcha_tk__=%S+".-data%-sitekey=.-') then
		if use_py_cloudflare then
			return self:solveWithPythonSelenium(url)
		end
		LOGGER.SendError('WebsitBypass[clounflare]: detected reCapthca challenge, not supported right now. can be redirected to third party capthca solver in the future\r\n' .. url)
		return -1
	end
	-- new IUAM challenge
	if ((rc == 429) or (rc == 503)) and body:find('window%._cf_chl_opt={') then
		if use_py_cloudflare then
			return self:solveWithPythonSelenium(url)
		end
		LOGGER.SendError('WebsitBypass[clounflare]: detected the new Cloudflare challenge, not supported yet\r\n' .. url)
		return 0
	end
	-- IUAM challenge
	if ((rc == 429) or (rc == 503)) and body:find('<form .-="challenge%-form" action="/.-__cf_chl_jschl_tk__=%S+"') then
		return self:solveIUAMChallenge(body, url)
	end
	
	if use_py_cloudflare then
		return self:solveWithPythonSelenium(url)
	end
	
	LOGGER.SendWarning('WebsitBypass[clounflare]: no Cloudflare solution found!\r\n' .. url)
	return -1
end

function fileExist(s)
	local f = io.open(s, 'r')
	local r = false
	if f then r = true f:close() end
	return r
end

function _m.bypass(self, METHOD, URL)
	duktape = require 'fmd.duktape'
	crypto = require 'fmd.crypto'
	fmd = require 'fmd.env'

	py_exe = "python"
	py_cloudflare = [[lua\websitebypass\cloudflare.py]]
	use_py_cloudflare = fileExist(py_cloudflare)

	local result = 0
	local counter = 0
	local maxretry = HTTP.RetryCount;
	-- most websites forced new challenge, consider disable it until further change
	-- local maxretry = 1;
	HTTP.RetryCount = 0

	while true do
		counter = counter + 1
		result = self:solveChallenge(URL)
		if result ~= 0 then break end
		if HTTP.Terminated then break end
		-- delay before retry
		self:sleepOrBreak(1000)
		if (maxretry > -1) and (maxretry <= counter) then break end
		HTTP.Reset()
		HTTP.Request('GET', URL)
	end

	HTTP.RetryCount = maxretry

	if result == 2 then -- need to reload
		return HTTP.Request(METHOD, URL)
	else
		return (result >= 1)
	end
end

return _m