###
// iphoneSlide - jQuery plugin
// @version: 0.8 (2012/03/03)
// @requires jQuery v1.4.3+
// @author Hina, Cain Chen. hinablue [at] gmail [dot] com
// @modified by: Adam Chow adamchow2326@yahoo.com.au
// Examples and documentation at: http://jquery.hinablue.me/jqiphoneslide
//
// Dual licensed under the MIT and GPL licenses:
// http://www.opensource.org/licenses/mit-license.php
// http://www.gnu.org/licenses/gpl.html
###

$ = jQuery

class iphoneslide

  "use strict"

  constructor: (options, callback, workspace) ->
    @workspace = $ workspace
    @_create options, callback

  m = Math

  defaults =
    handler: null,
    pageHandler : null,
    slideHandler : null,
    direction : 'horizontal',
    maxShiftPage : 5,
    responsive: false,
    draglaunch: 0.5,
    friction : 0.325,
    sensitivity : 20,
    extrashift : 800,
    touchduring : 800,
    easing: 'swing',
    bounce: true,
    pageshowfilter : false,
    autoPlay: false,
    cancelAutoPlayOnResize: true,
    autoCreatePager: false,
    pager:
      pagerType: 'dot',
      selectorName: '.banner_pager',
      childrenOnClass: 'on',
      slideToAnimated: true
    autoPlayTime: 3000,
    onShiftComplete : null

  workspace: null,
  handler: null,
  pagesHandler: null,
  totalPages: 0,
  matrixRow: 0,
  matrixColumn: 0,
  pagesOuterWidth: 0,
  pagesOuterHeight: 0,
  maxWidthPage: 0,
  maxHeightPage: 0,
  nowPage: 1,
  initiPhoneSlide: no,
  autoPlayerTimer: null,
  isTouch: no,
  isStartDrag: off,
  isPager: off,
  initDND: {},
  duringDND: {},
  posDND: {origX:0, origY:0, X:0, Y:0},
  boundry: {top:0, left:0, right:0, bottom:0},
  options: {},

  _updatepagernav: () ->
    opts = @options
    if @isPager is on
      $(opts.pager.selectorName).each (i, e) =>
        $("li", $(e)).removeClass(@options.pager.childrenOnClass)
        .eq(@nowPage-1).addClass(@options.pager.childrenOnClass)

  _createpager: () ->
    instance = @
    opts = @options

    return @ if @isPager is on

    switch opts.pager.pagerType
      when "number"
        pagerIndicator = 0
      when "dot"
        pagerIndicator = "&#8226"
      else
        pagerIndicator = ""

    pagerLinks = ''
    for i in [@totalPages..1]
      pagerLinks += '<li><span>'+(if typeof pagerIndicator is "number" then @totalPages-i+1 else pagerIndicator)+'</span></li>'

    if opts.pager.selectorName.charAt(0) is "."
      pagerHtml = $('<ul class="'+opts.pager.selectorName.substr(1, opts.pager.selectorName.length-1)+'"></ul>').html pagerLinks
    else if opts.pager.selectorName.charAt(0) is "#"
      pagerHtml = $('<ul id="'+opts.pager.selectorName.substr(1, opts.pager.selectorName.length-1)+'"></ul>').html pagerLinks
    else
      pagerHtml = $("<ul></ul>").html pagerLinks

    @isPager = on
    @workspace.parent().append pagerHtml

    $(pagerHtml).delegate("li", "click.iphoneslidepager", (event) ->
      event.preventDefault()
      clearInterval instance.autoPlayerTimer if instance.autoPlayerTimer
      instance.slide2page $(@).index()+1, opts.pager.slideToAnimated
    )

    if opts.autoPlay is on
      clearInterval @autoPlayerTimer if @autoPlayerTimer

      @autoPlayerTimer = setInterval () ->
        if instance.nowPage isnt instance.totalPages
          instance.slide2page "next"
        else
          instance.slide2page 1
      , opts.autoPlayTime


    pagerHtml = null
    pageLinks = null

    @_updatepagernav()

  _slidetopage: (easing) ->
    opts = @options
    easing = if typeof easing is "object" then easing else {X:0,Y:0}
    shift = {X:0, Y:0}
    animate = {before:{}, after:{}}
    outerWidthBoundary = @workspace.width()
    outerHeightBoundary = @workspace.height()
    nowPageElem = @pagesHandler.eq @nowPage-1

    shift.X = nowPageElem.position().left
    shift.X -= (outerWidthBoundary - nowPageElem.outerWidth(true))/2
    shift.Y = nowPageElem.position().top
    shift.Y -= (outerHeightBoundary - nowPageElem.outerHeight(true))/2

    switch opts.direction
      when "matrix"
        animate = {
          before: {top: -1*shift.Y+easing.Y, left: -1*shift.X+easing.X},
          after: {top: -1*shift.Y, left: -1*shift.X}
        }
      when "vertical"
        animate = {
          before: {top: -1*shift.Y+easing.Y},
          after: {top: -1*shift.Y}
        }
      when "horizontal"
        animate = {
          before: {left: -1*shift.X+easing.X},
          after: {left: -1*shift.X}
        }

    nowPageElem = null

    @_updatepagernav()

    return animate

  _getmovingdata: (pos, init, timestamp) ->
    opts = @options
    v = ex = 0
    w = @workspace.outerWidth() or @workspace.width()
    s = parseInt init
    e = parseInt pos
    t = parseInt timestamp

    v = m.abs(s-e)/m.abs(t);
    ex = m.floor(m.pow(v/12, 2)*m.abs(opts.extrashift)/(2*9.80665/12*m.abs(opts.friction))*0.01)
    ex = if s>w/2 then m.floor(w/3) else s

    return {speed:v, shift:ex}

  _click: (event) ->
    event.stopPropagation()
    currentTag = event.currentTarget.nodeName.toLowerCase()

    switch currentTag
      when "a"
        REGEX = ///http(s?)://.*///gi
        if REGEX.test event.currentTarget
          window.open event.currentTarget

      when "button", "input"
        $(event.currentTarget).trigger "click"
      else
        return true
    return true

  _stopdrag: (event) ->
    opts = @options

    return off if @isStartDrag is off

    if @isTouch is yes
        touches = event.originalEvent.touches or event.originalEvent.targetTouches or event.originalEvent.changedTouches

    stopEvent = if typeof touches is "undefined" then event else (if touches.length > 0 then touches[0] else {pageX: @duringDND.pageX, pageY: @duringDND.pageY, timeStamp: @duringDND.timestamp})

    if opts.slideHandler is null or typeof opts.slideHandler isnt "string"
      @workspace.undelegate opts.handler, "mousemove.iphoneslide touchmove.iphoneslide MozTouchMove.iphoneslide mouseup.iphoneslide mouseleave.iphoneslide touchend.iphoneslide touchcancel.iphoneslide"
    else
      @workspace.undelegate opts.slideHandler, "mousemove.iphoneslide touchmove.iphoneslide MozTouchMove.iphoneslide mouseup.iphoneslide mouseleave.iphoneslide touchend.iphoneslide touchcancel.iphoneslide"

    if m.max(m.abs(@initDND.origX-stopEvent.pageX),m.abs(@initDND.origY-stopEvent.pageY)) >= parseInt(opts.sensitivity)
      timestamp = m.abs(stopEvent.timeStamp - @initDND.timestamp)
      bounce = {width: @workspace.outerWidth(), height: @workspace.outerHeight()}
      thisPage = @pagesHandler.eq @nowPage-1
      thisPageSize = {width: thisPage.outerWidth(true), height: thisPage.outerHeight(true)}
      thisMove = {
        X: @_getmovingdata(stopEvent.pageX, @initDND.origX, timestamp),
        Y: @_getmovingdata(stopEvent.pageY, @initDND.origY, timestamp)
      }
      shift = {X:0, Y:0, shift: m.max(thisMove.X.shift, thisMove.Y.shift), speed: m.max(thisMove.X.speed, thisMove.Y.speed)}
      easing = {
        X: m.min(stopEvent.pageX - @initDND.origX, thisPageSize.width),
        Y: m.min(stopEvent.pageY - @initDND.origY, thisPageSize.height)
      }
      pages = {
        X: if m.abs(@posDND.X) >= bounce.width*opts.draglaunch or m.abs(@posDND.Y) >= bounce.height*opts.draglaunch then 0 else if timestamp > opts.touchduring then 1 else m.ceil(thisMove.X.speed*thisMove.X.shift/thisPageSize.width),
        Y: if m.abs(@posDND.X) >= bounce.width*opts.draglaunch or m.abs(@posDND.Y) >= bounce.height*opts.draglaunch then 0 else if timestamp > opts.touchduring then 1 else m.ceil(thisMove.Y.speed*thisMove.Y.shift/thisPageSize.height)
      }
      during = m.min(300, opts.touchduring, m.max(1/shift.speed*m.abs(opts.extrashift), m.abs(opts.extrashift)*0.5))

      switch opts.direction
        when "matrix"
          pageColumn = m.ceil(@nowPage/@matrixRow)
          pages.X = if pages.X>@matrixRow then @matrixRow else if m.abs(@posDND.X) < thisPageSize.width*opts.draglaunch then (if m.floor(m.abs(easing.Y/easing.X))>2 then 0 else pages.X) else (if easing.X>0 then m.min(pages.X, @nowPage-@matrixRow*(pageColumn-1)) else m.min(pages.X, @matrixRow*pageColumn-@nowPage))
          pages.Y = if pages.Y>@matrixColumn then @matrixColumn else if m.abs(@posDND.Y) < thisPageSize.height*opts.draglaunch then (if m.floor(m.abs(easing.X/easing.Y))>2 then 0 else pages.Y) else (if easing.Y>0 then m.min(pages.Y, pageColumn-1) else if @matrixRow*pages.Y+@nowPage>@totalPages then @matrixColumn-pageColumn else pages.Y)

          @nowPage = if easing.X>0 then (if @nowPage-pages.X<1 then 1 else @nowPage-pages.X) else (if @nowPage+pages.X>@totalPages then @totalPages else @nowPage+pages.X)
          @nowPage = if easing.Y>0 then (if @nowPage-pages.Y*@matrixRow<1 then 1 else @nowPage-pages.Y*@matrixRow) else (if pages.Y*@matrixRow>@totalPages then @totalPages else @nowPage+pages.Y*@matrixRow)

        when "vertical"
          pages.X = 0
          pages.Y = if pages.Y is 0 then 1 else if pages.Y > opts.maxShiftPage then opts.maxShiftPage else (if easing.Y>0 then (if @nowPage-pages.Y<1 then @nowPage-1 else pages.Y) else (if @nowPage+pages.Y>@totalPages then @totalPages - @nowPage else pages.Y))

          @nowPage = if easing.Y>0 then (if @nowPage-pages.Y<1 then 1 else @nowPage-pages.Y) else (if @nowPage+pages.Y>@totalPages then @totalPages else @nowPage+pages.Y)

        when "horizontal"
          pages.Y = 0
          pages.X = if pages.X is 0 then 1 else if pages.X>opts.maxShiftPage then opts.maxShiftPage else (if easing.X>0 then (if @nowPage-pages.X<1 then @nowPage-1 else pages.X) else (if @nowPage+pages.X>@totalPages then @totalPages-@nowPage else pages.X))

          @nowPage = if easing.X>0 then (if @nowPage-pages.X<1 then 1 else @nowPage-pages.X) else (if @nowPage+pages.X>@totalPages then @totalPages else @nowPage+pages.X)

      @nowPage = if @nowPage >= @totalPages then @totalPages else @nowPage

      animate = if opts.bounce is on then @_slidetopage easing else @_slidetopage 0

      @handler.animate animate.before, during if opts.bounce is on

      @handler.animate animate.after, 300, (if typeof $.easing[opts.easing] isnt "undefined" then opts.easing else "swing"), () =>
        @isStartDrag = off
        @_updatepagernav()
        @complete()
    else
      animate = @_slidetopage 0
      @handler.animate animate.after, 300

    thisPage = null
    stopEvent = null

    @isStartDrag = off

    return yes

  _startdrag: (event) ->
    opts = @options

    return @_stopdrag(event) if $.browser.msie and not event.button or @isStartDrag is off

    if @isStartDrag is on
      if @isTouch is yes
        touches = event.originalEvent.touches or event.originalEvent.targetTouches or event.originalEvent.changedTouches

      moveEvent = if typeof touches is "undefined" then event else touches[0]

      @duringDND = {
        pageX: moveEvent.pageX,
        pageY: moveEvent.pageY,
        timestamp: event.timeStamp
      }

      @posDND.X = parseInt(moveEvent.pageX - @initDND.origX)
      @posDND.Y = parseInt(moveEvent.pageY - @initDND.origY)

      switch opts.direction
        when "matrix"
          @handler.css({
            left: @posDND.origX + @posDND.X,
            top: @posDND.origY + @posDND.Y
          })
        when "vertical"
          @handler.css "top", @posDND.origY+@posDND.Y
        when "herizontal"
          @handler.css "left", @posDND.origX+@posDND.X

    if @isTouch is yes
      if @boundry.top > moveEvent.pageY or @boundry.left > moveEvent.pageX or @boundry.right < moveEvent.pageX or @boundry.bottom < moveEvent.pageY
        @_stopdrag event

    moveEvent = null

    return @isStartDrag

  _initdrag: (event) ->
    opts = @options

    clearInterval @autoPlayerTimer if @autoPlayerTimer isnt null
    return off if @isStartDrag is on

    if @isTouch is yes
      touches = event.originalEvent.touches or event.originalEvent.targetTouches or event.originalEvent.changedTouches

    @isStartDrag = on

    startEvent = if typeof touches is "undefined" then event else touches[0]

    @initDND = {
      timestamp: event.timeStamp,
      origX: startEvent.pageX,
      origY: startEvent.pageY
    }

    @posDND.origX = @posDND.X = @handler.position().left
    @posDND.origY = @posDND.Y = @handler.position().top

    if opts.slideHandler is null or typeof opts.slideHandler isnt "string"
      if not @isTouch
        @workspace.delegate(opts.handler, "mousemove.iphoneslide", (event) =>
          event.preventDefault()
          @_startdrag event
        ).delegate(opts.handler, "mouseleave.iphoneslide mouseup.iphoneslide", (event) =>
          event.preventDefault()
          @_stopdrag event
        )
      else
        @workspace.delegate(opts.handler, "touchmove.iphoneslide MozTouchMove.iphoneslide", (event) =>
          event.preventDefault()
          @_startdrag event
        ).delegate(opts.handler, "touchend.iphoneslide touchcancel.iphoneslide", (event) =>
          event.preventDefault()
          @_stopdrag event
        )
    else
      if not @isTouch
        @workspace.delegate(opts.slideHandler, "mousemove.iphoneslide", (event) =>
          event.preventDefault()
          @_startdrag event
        ).delegate(opts.slideHandler, "mouseleave.iphoneslide mouseup.iphoneslide", (event) =>
          event.preventDefault()
          @_stopdrag event
        )
      else
        @workspace.delegate(opts.slideHandler, "touchmove.iphoneslide MozTouchMove.iphoneslide", (event) =>
          event.preventDefault()
          @_startdrag event
        ).delegate(opts.slideHandler, "touchend.iphoneslide touchcancel.iphoneslide", (event) =>
          event.preventDefault()
          @_stopdrag event
        )

    startEvent = null

    return @isStartDrag

  _create: (options, callback) ->
    return @ if not @_init options

    opts = @options
    @nowPage = 1

    if not @isTouch
      if opts.slideHandler is null or typeof opts.slideHandler isnt "string"
        @workspace.delegate opts.handler, "mousedown.iphoneslide", (event) =>
          event.preventDefault()
          @_initdrag event
        @handler.delegate "a, button, input[type=button], input[type=reset], input[type=submit]", "mousedown.iphoneslide", (event) =>
          event.preventDefault()
          @_click event
      else
        @workspace.delegate opts.slideHandler, "mousedown.iphoneslide", (event) =>
          event.preventDefault()
          @_initdrag event
        @handler.filter(opts.slideHandler).delegate "a, button, input[type=button], input[type=reset], input[type=submit]", "mousedown.iphoneslide", (event) =>
          event.preventDefault()
          @_click event
    else
      if opts.slideHandler is null or typeof opts.slideHandler isnt "string"
        @workspace.delegate opts.handler, "touchstart.iphoneslide MozTouchDown.iphoneslide", (event) =>
          event.preventDefault()
          @_initdrag event
        @handler.delegate "a, button, input[type=button], input[type=reset], input[type=submit]", "touchstart.iphoneslide MozTouchDown.iphoneslide", (event) =>
          event.preventDefault()
          @_click event
      else
        @workspace.delegate opts.slideHandler, "touchstart.iphoneslide MozTouchDown.iphoneslide", (event) =>
          event.preventDefault()
          @_initdrag event
        @handler.filter(opts.slideHandler).delegate "a, button, input[type=button], input[type=reset], input[type=submit]", "touchstart.iphoneslide MozTouchDown.iphone?slide", (event) =>
          event.preventDefault()
          @_click event

    @_createpager() if opts.autoCreatePager is on and not @isPager

    $(window).resize () =>
      clearInterval @autoPlayerTimer if @autoPlayerTimer and opts.cancelAutoPlayOnResize
      @reset()

    callback.call(@) if $.isFunction callback is on

  _init: (options) ->
    opts = @options = $.extend({}, defaults, options)
    tmpPage = @nowPage or 1

    if opts.handler is null or typeof opts.handler isnt "string"
      opts.handler = ".iphone-slide-page-handler"
      @workspace.children(":first").addClass("iphone-slide-page-handler")
      @options = opts

    @isTouch = @touch()
    @handler = $ opts.handler, @workspace

    return false if @handler.children().size() is 0

    if opts.pageHandler is null or typeof opts.pageHandler isnt "string"
      switch @handler.attr('tagName').toLowerCase()
        when "ul", "ol"
          opts.pageHandler = 'li'
        else
          opts.pageHandler = @handler.children(':first').attr('tagName').toLowerCase()

    if not opts.pageshowfilter
      @pagesHandler = @handler.children(opts.pageHandler)
    else
      @pagesHandler = @handler.children(opts.pageHandler).filter(':visible')

    @totalPages = @pagesHandler.length
    @_setBoundry()
    @nowPage = 0
    @slide2page tmpPage
    @pagesHandler.css 'display', 'block'

    return @

  _setBoundry: () ->
    opts = @options
    maxPageSize = @_getMaxPageSize()

    switch opts.direction
      when "matrix"
        @matrixRow = m.ceil(m.sqrt(@totalPages))
        @matrixColumn = m.ceil(@totalPages/@matrixRow)
        @pagesOuterWidth = maxPageSize.width * @matrixRow
        @pagesOuterHeight = maxPageSize.height * @matrixColumn
        @handler.width(@pagesOuterWidth).height(@pagesOuterHeight)

        if not opts.responsive
          @pagesHandler.each (i, elem) ->
            elem = $(elem)
            _w = elem.outerWidth()
            _h = elem.outerHeight()

            if _w < maxPageSize.width
              elem.css {
                'margin-left': (maxPageSize.width - _w)/2,
                'margin-right': (maxPageSize.width - _w)/2
              }
            if _h < maxPageSize.height
              elem.css {
                'margin-top': (maxPageSize.height - _h)/2,
                'margin-bottom': (maxPageSize.height -_h)/2
              }

            elem = null
        else
          @pagesHandler.width(maxPageSize.width).height(maxPageSize.height)

        for i in [@matrixColumn..1]
          $('<br class="matrix-break-point" style="clear:both;">').insertAfter @pagesHandler.eq((i-1)*@matrixRow-1)

        @workspace.width(maxPageSize.width).height(maxPageSize.height)

      when "vertical"
        @pagesOuterWidth = maxPageSize.width

        if not opts.responsive
          @pagesHandler.each (i, elem) =>
            elem = $(elem)
            _h = elem.outerHeight(true)
            _w = elem.outerWidth(true)

            @pagesOuterHeight += _h

            if _w < maxPageSize.width
              elem.css 'margin-left', (maxPageSize - _w)/2

            elem = null
        else
          @pagesOuterHeight = @pagesHandler.size() * maxPageSize.height
          @pagesHandler.width(maxPageSize.width).height(maxPageSize.height)

        @handler.height(@pagesOuterHeight).width(@pagesOuterWidth)
        .css('top', (maxPageSize.height-@pagesHandler.eq(0).outerHeight(true))/2)

        @workspace.width maxPageSize.width

      when "horizontal"
        @pagesOuterHeight = maxPageSize.height

        if not opts.responsive
          @pagesHandler.each (i, elem) =>
            elem = $(elem)
            _w = elem.outerWidth(true)
            _h = elem.outerHeight(true)

            @pagesOuterWidth += _w

            if _h < maxPageSize.height
              elem.css 'margin-top', (maxPageSize.height - _h)/2

            elem = null
        else
          @pagesOuterWidth = @pagesHandler.size() * maxPageSize.width
          @pagesHandler.width(maxPageSize.width).height(maxPageSize.height)

        @handler.width(@pagesOuterWidth).height(@pagesOuterHeight)
        .css('left', (maxPageSize.width-@pagesHandler.eq(0).outerWidth(true))/2)

        @workspace.height maxPageSize.height

    @boundry = {
      top: @workspace.position().top,
      left: @workspace.position().left,
      right: @workspace.position().left + @workspace.width(),
      bottom: @workspace.position().top + @workspace.height()
    }

  _getMaxPageSize: () ->
    opts = @options

    return {width: @workspace.width(), height: @workspace.height()} if opts.responsive is yes

    maxWidthPage = 0
    maxHeightPage = 0

    @pagesHandler.each (i, elem) ->
      elem = $(elem)
      _w = elem.outerWidth(true)
      _h = elem.outerHeight(true)

      maxWidthPage = if _w >= maxWidthPage then _w else maxWidthPage
      maxHeightPage = if _h >= maxHeightPage then _h else maxHeightPage

      elem = null

    return {width: maxWidthPage, height: maxHeightPage}

  slide2page: (page, effect) ->
    opts = @options
    page or= 1
    effect = if typeof effect is "boolean" then effect else true

    if typeof page is "string"
      switch page
        when "prev"
          page = @nowPage-1
        when "next"
          page = @nowPage+1

    return off if page <=0 or page > @totalPages or page is @nowPage

    @nowPage = page

    animate = @_slidetopage page

    if effect is on
      @handler.animate animate.after, 300, (if typeof $.easing[opts.easing] isnt "undefined" then opts.easing else "swing"), () =>
        @complete()
    else
      @handler.css animate.after
      @complete()

    return @

  blank2page: (content, jump2page, callback) ->
    opts = @options

    if typeof content is "string"
      content = [content]
    else
      content = [] if not $.isArray content

    jump2page = no if typeof jump2page isnt "boolean"

    if typeof jump2page is "function"
      callback = jump2page
    else
      callback = null if typeof callback isnt "function"

    if content.length > 0
      firstElem = @pagesHandler.eq 0
      @nowPage = if jump2page is yes then @totalPages+1 else @nowPage

      $.each content, (index, html) =>
        firstElem.clone().removeAttr('style').html(html).appendTo(@handler)
        if index is content.length-1
          @_init(opts).slide2page @nowPage

    return @

  reset: () ->
    @_setBoundry()

    return @

  complete: () ->
    opts = @options

    return no if typeof opts.onShiftComplete isnt "function"

    opts.onShiftComplete.apply @, [@pagesHandler.eq(@nowPage-1), @nowPage]

    return @

  update: (key) ->
    key = key or {}
    if $.isPlainObject key is yes
      @options = $.extend {}, @options, key
      return

  touch: () ->
    userAgent = navigator.userAgent or navigator.vendor or window.opera
    REGEX = ///
      android.+(mobile|pad)|avantgo|bada/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od|ad)|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino///i
    REGEX2 = ///1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |/)|klon|kpt |kwc-|kyo(c|k)|le(no|xi)|lg( g|/(k|l|u)|50|54|e-|e/|\-[a-w])|libw|lynx|m1\-w|m3ga|m50/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55/|sa(ge|ma|mm|ms|ny|va)|sc(01|h-|oo|p-)|sdk/|se(c(-|0|1)|47|mc|nd|ri)|sgh-|shar|sie(-|m)|sk-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|xda(\-|2|g)|yas\-|your|zeto|zte\-///i

    if REGEX.test(userAgent) or REGEX2.test(userAgent.substr(0,4))
      return yes
    else
      return no

$.fn.iphoneSlide = (options, callback) ->
  switch typeof options
    when "string"
      args = Array.prototype.slice.call arguments, 1
      @each(() ->
        instance = $.data @, 'iphoneslide'
        return no if not instance
        return no if not $.isFunction instance[options] or options.charAt 0 is "_"

        instance[options].apply instance, args
      )
    when "object"
      @each(() ->
        instance = $.data @, 'iphoneslide'
        if not instance
          $.data @, 'iphoneslide', new iphoneslide(options, callback, @)
        else
          instance.update options
      )
  return this
