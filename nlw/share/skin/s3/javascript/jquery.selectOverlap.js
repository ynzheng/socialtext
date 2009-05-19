(function($){
    $.fn.createSelectOverlap = function() {
        var opts = {};
        if (arguments.length) opts = arguments[0];
        if ($.browser.msie && $.browser.version < 7) {
            this.each(function(){
                var $iframe = $('iframe.iframeHack', this);
                if ($iframe.size() == 0) {
                    $iframe = $('<iframe src="javascript:false"></iframe>')
                        .addClass('iframeHack')
                        .css({
                            position: 'absolute',
                            filter: "alpha(opacity=0)",
                            top:    -1,
                            left:   -1,
                            zIndex: opts.zIndex || -1
                        })
                        .appendTo(this);
                }

                $(this).mouseover(function() {
                    $iframe.css({
                        width:  $(this).width() + 2,
                        height: $(this).height() + 2
                    });
                });
                $iframe.css({
                    width:  $(this).width() + 2,
                    height: $(this).height() + 2
                });
            });
        }
        return this;
    };
})(jQuery);
