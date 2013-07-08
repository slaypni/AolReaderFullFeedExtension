chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    getFunction = ->
        obj = window
        for prop in request.fnname.split('.')
            obj = obj[prop]
        return obj

    switch request.type
        when 'call'
            fn = getFunction()
            response = fn.apply(this, request.args)
            sendResponse(response)
        when 'callWithCallback'
            fn = getFunction()
            fn.apply(this, request.args.concat(sendResponse))
        when 'getTab'
            sendResponse(sender.tab)
        when 'getSettings'
            storage.getSettings (settings) ->
                sendResponse(settings)
        when 'setSettings'
            storage.setSettings request.settings, (settings) ->
                sendResponse(settings)
        when 'getContent'
            url = request.url

            chrome.webRequest.onHeadersReceived.addListener(
                (details) ->
                    for header in details.responseHeaders when header.name?.toLowerCase() == 'location'
                        url = header.value  # affect to retrieve xpath data from database
                        break
                    chrome.webRequest.onHeadersReceived.removeListener(arguments.callee)
                    return {}
                , {
                    urls: [url]
                    types: ['xmlhttprequest']
                }
                , [
                    'responseHeaders'
                    'blocking'
                ]
            )
            
            xhr = new XMLHttpRequest()
            xhr.open('GET', url, true)
            xhr.responseType = 'document'
            xhr.onload = ->
                doc = xhr.response
                if doc?
                    getContent = (cb) ->
                        getXPath url, (xpath) ->
                            res = null
                            if xpath?
                                res = doc.evaluate(xpath, doc, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
                                res = res.parentElement if res?.nodeType == Node.TEXT_NODE
                            if not res?
                                if (elem = doc.querySelector(CANDIDATE_SELECTORS.join(',')))?
                                    res = elem
                                else
                                    ex = new ExtractContentJS.LayeredExtractor()
                                    ex.addHandler(ex.factory.getHandler('Heuristics'))
                                    exres = ex.extract(doc, url)
                                    if exres.isSuccess?
                                        node = exres.content.asNode()
     
                                        filterOutSiblings = ->
                                            filter_outs = Array.prototype.slice.call(node.children, 0)
                                            for leaf in exres.content.asLeaves()
                                                elem = leaf.node
                                                while elem?
                                                    parent = elem.parentElement
                                                    if parent == node
                                                        filter_outs = _.without(filter_outs, elem)
                                                        break
                                                    elem = parent
                                            for elem in filter_outs
                                                node.removeChild(elem)
                                        # filterOutSiblings()
     
                                        res = node

                            CompleteLinks = ->
                                complete = (elems, prop)->
                                    for elem in elems
                                        link = elem.attributes[prop]?.value
                                        continue if (not link?) or link.length == 0
                                        continue if link.match(/.*\/\//)?
                                        link = link.trim()
                                        elem[prop] = (if link[0] != '#' then url.match(/(.+\/)/)[1] else url) + link[(if link[0] == '/' then 1 else 0)..]
                                complete(doc.querySelectorAll('img'), 'src')
                                complete(doc.querySelectorAll('a'), 'href')
                            CompleteLinks()
     
                            cb?((new XMLSerializer()).serializeToString(res)) if res?

                    getContent (res) ->
                        sendResponse?(res) if res?
                        
            xhr.send()
    return true


_candidates = null

getXPath = (url, cb) ->
    get = ->
        for cand in _candidates
            return cand.xpath if url.match(cand.re)?
        return null
        
    if not _candidates?
        xhr = new XMLHttpRequest()
        xhr.open('GET', 'http://wedata.net/databases/LDRFullFeed/items_all.json', true)
        xhr.onload = ->
            _candidates = []
            items = JSON.parse(xhr.response)
            _candidates = ({re: item.data.url, xpath: item.data.xpath } for item in items when item.data? and item.data.url? and item.data.xpath?)
            cb?(get())
        xhr.onerror = ->
            cb?()
        xhr.send()
    else
        cb?(get())
