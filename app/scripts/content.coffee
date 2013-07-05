# require hapt.js, underscore.js, jquery.js

_settings = null

callbg = (cb, fnname, args...) ->
    chrome.runtime.sendMessage {type: 'call', fnname: fnname, args: args}, (response) ->
        cb?(response)

callbgcb = (cb, fnname, args...) ->
    chrome.runtime.sendMessage {type: 'callWithCallback', fnname: fnname, args: args}, (response) ->
        cb?(response)
        
haptListen = (cb) ->
    hapt.listen( (keys, event) ->
        if not (event.target.isContentEditable or event.target.nodeName.toLowerCase() in ['textarea', 'input', 'select'])
            return cb(keys, event)
        return true
    , window, true, [])

chrome.runtime.sendMessage {type: 'getSettings'}, (settings) ->
    _settings = settings

    hapt_listener = haptListen (_keys) ->
        keys = _keys.join(' ')
        if keys in (binding.join(' ') for binding in _settings.bindings.load_full_feed)
            ActiveArticle.get()?.loadFullFeed()

$ ->
    $('body').on 'DOMNodeInserted', (e) ->
        article = ActiveArticle.get()

class ActiveArticle
    _instance = null
    _dom_element = null
    
    @get: ->
        element = $('.article-item-active, .dialog.article-item').has('.article-header.clearfix').first()
        if element.length == 0
            _instance = _dom_element = null
        else 
            dom_element = element.get(0)
            if dom_element != _dom_element
                _dom_element = dom_element
                _instance = new _Article(element)
        return _instance

    class _Article
        constructor: (@article_element) ->
            construct = =>
                @article_content_element = @article_element.find('.article-content').first() if not (@article_content_element?.length > 0)
                if @article_content_element?.length > 0
                    @url = @article_content_element.find('a').first().prop('href') if not @url?
                    @article_body_element = @article_content_element.find('.article-body').first() if not (@article_body_element?.length > 0)

                @article_header_element = @article_element.find('.article-header.clearfix').first() if not (@article_header_element?.length > 0)
                if @article_header_element?.length > 0
                    @btn_group_wrap_element = @article_header_element.find('.btn-group-wrap').first() if not (@btn_group_wrap_element?.length > 0)
                    if @btn_group_wrap_element?.length > 0
                        addButton = =>
                            @button = $('<div class="btn-group"><span class="btn-icon with-tip" title data-original-title="View Article"><i class="icon-view-article"></i></span></div>')
                            @btn_group_wrap_element.prepend(@button)
                            @button.click =>
                                @loadFullFeed()
                        addButton() if not @button?
                @loadFullFeed() if _settings?.load_automatically and @button? and @url? and not @isLoaded
            @article_element.on 'DOMNodeInserted', construct
            construct()

        loadFullFeed: =>
            if not @url? then return
            chrome.runtime.sendMessage {type: 'getContent', url: @url}, (res) =>
                content = $(res)
                content.find('img').addClass('fullfeed')
                @article_body_element?.html(content)
                @isLoaded = true
