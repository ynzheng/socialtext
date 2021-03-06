/*
 * Lookahead implementation in jQuery
 *
 * Usage:
 *
 * jQuery('#my-input')
 *    .lookahead({
 *       // REST url to fetch the suggestion list from
 *       url: '/data/workspaces',
 *
 *       // Number of items to display
 *       count: 10, //default
 *
 *       // OR a function that returns the rest url
 *       url: function () { return '/data/workspaces' },
 *
 *       // Function called on each list item which turns the item hash
 *       // into an array containing the link title and value
 *       // or a value to use both as the link title and value
 *       linkText: function (item) {
 *           return [ item.title, item.value ];
 *           // OR
 *           return item.value;
 *       }
 *
 *       // OPTIONAL: modify the value before searching
 *       filterValue: function (val) {
 *           return val + '.*(We)?blog$'
 *       },
 *
 *       // OPTIONAL: use this function to change the way the result is
 *       // displayed in the input box
 *       displayAs: function (item) {
 *           return item.title;
 *       }
 *
 *       // OPTIONAL: use a different filter argument than 'filter'
 *       filterName: 'title_filter',
 *
 *       // OPTIONAL: handler run when a value is accepted
 *       onAccept: function (val, item) {
 *       },
 *
 *       // OPTIONAL: handler run when a user first types into the input
 *       onFirstType: function(input) {
 *            input.val("");
 *            input.removeClass("prompt");
 *       },
 *
 *       // NOT IMPLEMENTED: additional args to pass to the server
 *       args: { pageType: 'spreadsheet' }
 *
 *    });
 */

(function($){
    var lookaheads = [];

    var hastyped = false;

    var DEFAULTS = {
        count: 10,
        filterName: 'filter',
        requireMatch: false,
        params: { 
            order: 'alpha',
            count: 30 // for fetching
        }
    };

    var KEYCODES = {
        DOWN: 40,
        UP: 38,
        ENTER: 13,
        SHIFT: 16,
        ESC: 27,
        TAB: 9
    };

    Lookahead = function (input, opts) {
        if (!input) throw new Error("Missing input element");
        if (!opts.url) throw new Error("url missing");
        if (!opts.linkText) throw new Error("linkText missing");

        var targetWindow = opts.getWindow && opts.getWindow();
        if (targetWindow) {
            this.window = targetWindow;
            this.$ = targetWindow.$;
        }

        this._items = [];
        this.input = input;
        this.opts = $.extend(true, {}, DEFAULTS, opts); // deep extend
        var self = this;

        if (this.opts.clickCurrentButton) {
            this.opts.clickCurrentButton.click(function() {
                self.clickCurrent();
                return false;
            });
        }

        $(this.input)
            .attr('autocomplete', 'off')
            .unbind('keyup')
            .keyup(function(e) {
                if (e.keyCode == KEYCODES.ESC) {
                    $(input).val('').blur();
                    self.clearLookahead();
                }
                else if (e.keyCode == KEYCODES.ENTER) {
                    if (self.opts.requireMatch) {
                        if (self._items.length) {
                            self.clickCurrent();
                        }
                    }
                    else {
                        self.acceptInputValue();
                    }
                }
                else if (e.keyCode == KEYCODES.DOWN) {
                    self.selectDown();
                }
                else if (e.keyCode == KEYCODES.UP) {
                    self.selectUp();
                }
                else if (e.keyCode != KEYCODES.TAB && e.keyCode != KEYCODES.SHIFT) {
                    self.onchange();
                }
                return false;
            })
            .unbind('keydown')
            .keydown(function(e) {
                if (!self.hastyped) {
                    self.hastyped=true;
                    if (self.opts.onFirstType) {
                        self.opts.onFirstType($(self.input));
                    }
                }
                if (self.lookahead && self.lookahead.is(':visible')) {
                    if (e.keyCode == KEYCODES.TAB) {
                        self.clickCurrent();
                        return false;
                    }
                    else if (e.keyCode == KEYCODES.ENTER) {
                        return false;
                    }
                }
            })
            .unbind('blur')
            .blur(function(e) {
                setTimeout(function() {
                    if (self._accepting) {
                        self._accepting = false;
                        $(self.input).focus();
                    }
                    else {
                        self.clearLookahead();
                        if ($.isFunction(self.opts.onBlur)) {
                            self.opts.onBlur(action);
                        }
                    }
                }, 50);
            });

        this.allowMouseClicks();
    }

    $.fn.lookahead = function(opts) {
        this.each(function(){
            lookaheads.push(new Lookahead(this, opts));
        });

        return this;
    };

    Lookahead.prototype = {
        'window': window,
        '$': window.$
    };

    Lookahead.prototype.allowMouseClicks = function() { 
        var self = this;

        var elements = [ this.getLookahead() ];
        if (this.opts.allowMouseClicks)
            elements.push(this.opts.allowMouseClicks);

        $.each(elements, function () {
            $(this).unbind('mousedown').mousedown(function() {
                // IE: Use _accepting to prevent onBlur
                if ($.browser.msie) self._accepting = true;
                $(self.input).focus();
                // Firefox: This works because this is called before blur
                return false;
            });
        });
    };

    Lookahead.prototype.clearLookahead = function () {
        this._cache = {};
        this._items = [];
        this.hide();
    };

    Lookahead.prototype.getLookahead = function () {
        /* Subract the offsets of all absolutely positioned parents
         * so that we can position the lookahead directly below the
         * input element. I think jQuery's offset function should do
         * this for you, but maybe they'll fix it eventually...
         */
        var left = $(this.input).offset().left;
        var top = $(this.input).offset().top + $(this.input).height() + 10;
        var width = $(this.input).width();

        if (this.window !== window) {
            // XXX: container specific
            var offset = this.$('iframe[name='+window.name+']').offset();
            left += offset.left;
            top += offset.top;
        }

        if (!this.lookahead) {
            this.lookahead = this.$('<div></div>')
                .hide()
                .css({
                    textAlign: 'left',
                    zIndex: 3001,
                    position: 'absolute',
                    display: 'none', // Safari needs this explicitly: {bz: 2431}
                    background: '#B4DCEC',
                    border: '1px solid black',
                    padding: '0px'
                })
                .prependTo('body');

            this.$('<ul></ul>')
                .css({
                    listStyle: 'none',
                    padding: '0'
                })
                .appendTo(this.lookahead);

        }

        this.lookahead.css({
            width: width + 'px',
            left: left + 'px',
            top: top + 'px'
        });

        return this.lookahead;
    };

    Lookahead.prototype.getLookaheadList = function () {
        return this.$('ul', this.getLookahead());
    };

    Lookahead.prototype.linkTitle = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[0];
    };

    Lookahead.prototype.linkValue = function (item) {
        var lt = this.opts.linkText(item);
        return typeof (lt) == 'string' ? lt : lt[1];
    };

    Lookahead.prototype.filterRE = function (val) {
        return new RegExp('\\b(' + val + ')', 'ig');
    };
    
    Lookahead.prototype.filterData = function (val, data) {
        var self = this;

        var filtered = [];
        var re = this.filterRE(val);

        $.each(data, function() {
            if (filtered.length >= self.opts.count) return;

            var title = self.linkTitle(this);
            if (title.match(re)) {
                filtered.push({
                    bolded_title: title.replace(re, '<b>$1</b>'),
                    title: title,
                    value: self.linkValue(this)
                });
            }
        });

        return filtered;
    };

    Lookahead.prototype.displayData = function (data) {
        var self = this;
        this._items = data;
        var lookaheadList = this.getLookaheadList();
        lookaheadList.html('');

        if (data.length) {
            $.each(data, function (i) {
                var item = this || {};
                var li = self.$('<li></li>')
                    .css({ padding: '3px 5px' })
                    .appendTo(lookaheadList);
                self.$('<a href="#"></a>')
                    .html(item.bolded_title)
                    .attr('value', i)
                    .click(function() {
                        self.accept(i);
                        return false;
                    })
                    .appendTo(li);
                if (i==0) {
                    self.select_element(li, true);
                }
            });
            this.show();
        }
        else {
            lookaheadList.html('<li></li>');
            $('li', lookaheadList)
                .text("No matches for '"+$(this.input).val()+"'")
                .css({padding: '3px 5px'});
            this.show();
        }
    };

    Lookahead.prototype.show = function () {
        var self = this;
        var lookahead = this.getLookahead();
        if (!lookahead.is(':visible')) {
            lookahead.fadeIn(function() {
                self.allowMouseClicks();
                if ($.isFunction(self.opts.onShow)) {
                    self.opts.onShow();
                }
            });
        }

        // IE6 iframe hack:
        // Enabling the select overlap breaks clicking on the lookahead if the
        // lookahead is inserted into a different window.
        // NOTE: We cannot have "zIndex:" here, otherwise elements in the
        // lookahead become unclickable and causes {bz: 2597}.
        if (window === this.window)
            this.lookahead.createSelectOverlap({ padding: 1 });
    };

    Lookahead.prototype.hide = function () {
        var lookahead = this.getLookahead();
        if (lookahead.is(':visible')) {
            lookahead.fadeOut();
        }
    };

    Lookahead.prototype.acceptInputValue = function() {
        var value = $(this.input).val();
        this.clearLookahead();

        if (this.opts.onAccept) {
            this.opts.onAccept.call(this.input, value, {});
        }
    };

    Lookahead.prototype.accept = function (i) {
        if (!i) i = 0; // treat undefined as 0
        var item;
        if (arguments.length) {
            item = this._items[i];
            this.select(item);
        }
        else if (this._selected) {
            // Check if we are displaying the last selected value
            if (this.displayAs(this._selected) == $(this.input).val()) {
                item = this._selected;
            }
        }

        var value = item ? item.value : $(this.input).val();

        this.clearLookahead();

        if (this.opts.onAccept) {
            this.opts.onAccept.call(this.input, value, item);
        }
    }

    Lookahead.prototype.displayAs = function (item) {
        if ($.isFunction(this.opts.displayAs)) {
            return this.opts.displayAs(item);
        }
        else if (item) {
            return item.value;
        }
        else {
            return $(this.input).val();
        }
    }

    Lookahead.prototype.select = function (item, provisional) {
        this._selected = item;
        if (!provisional) {
            $(this.input).val(this.displayAs(item));
        }
    }
    
    Lookahead.prototype._highlight_element = function (el) {
        jQuery('li.selected', this.lookahead)
            .removeClass('selected')
            .css({ background: '' });
        el.addClass('selected').css({ background: '#7DBFDB' });
    }

    Lookahead.prototype.select_element = function (el, provisional) {
        this._highlight_element(el);
        var value = el.children('a').attr('value');
        var item = this._items[value];
        this.select(item, provisional);
    }

    Lookahead.prototype.selectDown = function () {
        if (!this.lookahead) return;
        var el;
        if (jQuery('li.selected', this.lookahead).length) {
            el = jQuery('li.selected', this.lookahead).next('li');
        }
        if (! (el && el.length) ) {
            el = jQuery('li:first', this.lookahead);
        }
        this.select_element(el, false);
    };

    Lookahead.prototype.selectUp = function () {
        if (!this.lookahead) return;
        var el;
        if (jQuery('li.selected', this.lookahead).length) {
            el = jQuery('li.selected', this.lookahead).prev('li');
        }
        if (! (el && el.length) ) {
            el = jQuery('li:last', this.lookahead);
        }
        this.select_element(el, false);
    };

    Lookahead.prototype.clickCurrent = function () {
        if (this._items.length) {
            var selitem = jQuery('li.selected a', this.lookahead);
            if (selitem.length && selitem.attr('value')) {
                this.accept(selitem.attr('value'));
            }
        }
    };

    Lookahead.prototype.storeCache = function (val, data) {
        this._cache = this._cache || {};
        this._cache[val] = data;
        this._prevVal = val;
    }

    Lookahead.prototype.getCached = function (val) {
        this._cache = this._cache || {};

        if (this._cache[val]) {
            // We've already done this query, so just return this data
            return this.filterData(val, this._cache[val])
        }
        else if (this._prevVal) {
            var re = this.filterRE(this._prevVal);
            if (val.match(re)) {
                // filter the previous data, but only return if we still
                // have at least the minimum or if filtering the data made
                // no difference
                var cached = this._cache[this._prevVal];
                if (cached) {
                    filtered = this.filterData(val, cached)
                    var use_cache = cached.length == filtered.length
                                 || filtered.length >= this.opts.count;
                    if (use_cache) {
                        // save this for next time
                        this.storeCache(val, cached);
                        return filtered;
                    }
                }
            }
        }
        return [];
    };

    Lookahead.prototype.onchange = function () {
        var self = this;
        if (this._loading_lookahead) return;

        var val = $(this.input).val();
        if (!val) {
            this.clearLookahead()
            return;
        }

        var cached = this.getCached(val);
        if (cached.length) {
            this.displayData(cached);
            return;
        }

        var url = typeof(this.opts.url) == 'function'
                ? this.opts.url() : this.opts.url;

        var params = this.opts.params;
        if (this.opts.filterValue)
            val = this.opts.filterValue(val);
        params[this.opts.filterName] = '\\b' + val;

        this._loading_lookahead = true;
        $.ajax({
            url: url,
            data: params,
            cache: false,
            dataType: 'json',
            success: function (data) {
                self.storeCache(val, data);
                self._loading_lookahead = false;
                self.displayData(
                    self.filterData(val, data)
                );
            },
            error: function (xhr, textStatus, errorThrown) {
                self._loading_lookahead = false;
                var $error = this.$('<span"></span>')
                    .addClass("st-suggestion-warning");
                this.$('<li></li>')
                    .append($error)
                    .appendTo(self.getLookaheadList());

                if (textStatus == 'parsererror') {
                    $error.html(loc("Error parsing data"));
                }
                else if (self.opts.onError) {
                    var errorHandler = self.opts.onError[xhr.status]
                                    || self.opts.onError['default'];
                    if (errorHandler) {
                        if ($.isFunction(errorHandler)) {
                            $error.html(
                                errorHandler(xhr, textStatus, errorThrown)
                            );
                        }
                        else {
                            $error.html(errorHandler);
                        }
                    }
                }
                else {
                    $error.html(textStatus);
                }
                self.show();
            }
        });
    };

})(jQuery);
