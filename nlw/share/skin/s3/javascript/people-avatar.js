(function($){

Person = function (user) {
    $.extend(true, this, user);
}

Person.prototype = {
    isSelf: function() {
        return this.self || (Socialtext.email_address == this.email);
    },

    isFollowing: function() {
        return Socialtext.watchlist[this.id] ? true : false;
    },

    updateFollowLink: function() {
        var linkText = this.linkText();
        this.node.text(linkText).attr('title', linkText);
    },

    linkText: function() {
        return this.isFollowing() ? loc('Stop Following this person')
                                  : loc('Follow this person');
    },

    createFollowLink: function() {
        var self = this;
        if (!this.isSelf()) {
            var link_text = this.linkText();
            this.node = $('<a href="#"></a>')
                .addClass('followPersonButton')
                .click(function(){ 
                    self.isFollowing() ? self.stopFollowing() : self.follow();
                    return false;
                });
            this.updateFollowLink();
            return this.node;
        }
    },

    follow: function() {
        var self = this;
        $.ajax({
            url:'/data/people/' + Socialtext.userid + '/watchlist', 
            type:'POST',
            contentType: 'application/json',
            processData: false,
            data: '{"person":{"id":"' + this.id + '"}}',
            success: function() {
                Socialtext.watchlist[self.id] = self.best_full_name;
                self.updateFollowLink();
                self.addPeopleEntry();
            }
        });
    },

    stopFollowing: function() {
        var self = this;
        $.ajax({
            url:'/data/people/' + Socialtext.userid + '/watchlist/' + this.id,
            type:'DELETE',
            contentType: 'application/json',
            success: function() {
                delete Socialtext.watchlist[self.id];
                self.updateFollowLink();
                self.removePeopleEntry();
            }
        });
    },

    addPeopleEntry: function() {
        $('<li></li>')
            .attr('id', "people-link-" + this.id)
            .append(
                $('<img/>')
                    .attr('src', '/data/people/' + this.id + '/small_photo'),
                $('<a></a>')
                    .attr('href', "/?profile/" + this.id)
                    .text(this.best_full_name)
            )
            .appendTo('#global-people-directory');
    },

    removePeopleEntry: function() {
        $('#global-people-directory li#people-link-' + this.id).remove();
    }
}

Avatar = function (node) {
    var self = this;
    this.node = node;
    $(node).mouseover(function(){ self.mouseOver() });
    $(node).mouseout(function(){ self.mouseOut() });
};

Avatar.prototype = {
    HOVER_TIMEOUT: 500,

    mouseOver: function() {
        this._state = 'showing';
        var self = this;
        setTimeout(function(){
            if (self._state == 'showing') {
                self.displayAvatar();
                self._state = 'shown';
            }
        }, this.HOVER_TIMEOUT);
    },

    mouseOut: function() {
        this._state = 'hiding';
        var self = this;
        setTimeout(function(){
            if (self._state == 'hiding') {
                self.hide();
                self._state = 'hidden';
            }
        }, this.HOVER_TIMEOUT);
    },

    createPopup: function() {
        var self = this;
        this.contentNode = $('<div></div>')
            .addClass('inner');

        this.popup = $('<div></div>')
            .addClass('avatarPopup')
            .mouseover(function() { self.mouseOver() })
            .mouseout(function() { self.mouseOut() })
            .append(this.contentNode)
            .appendTo('body');

        var $img1 = $('<img/>')
            .addClass('top')
            .attr('src', nlw_make_s3_path('/images/avatarPopupTop.png'))
            .prependTo(this.popup);
        this.makeTransparent($img1);

        // Add quote bubbles
        var $img2 = $('<img/>')
            .addClass('bottom')
            .attr('src', nlw_make_s3_path('/images/avatarPopupBottom.png'))
            .appendTo(this.popup);
        this.makeTransparent($img2);
    },

    makeTransparent: function($img) {
	if ($.browser.msie && $.browser.version < 7) {
            var args = "src='" + $img.attr('src') + "', sizingMethod='scale'";
            var filter = "progid:DXImageTransform.Microsoft"
                       + ".AlphaImageLoader(" + args + ")";

            $('<div></div>')
                .insertAfter($img)
                .attr('class', $img.attr('class'))
                .css({
                    'filter': filter,
                    'height': '19px',
                    'width': '252px'
                });
            $img.remove();
        }
    },

    getUserInfo: function(userid) {
        this.id = userid;
        var self = this;
        $.ajax({
            url: '/data/people/' + userid,
            cache: false,
            dataType: 'html',
            success: function (html) {
                self.showUserInfo(html);
            },
            error: function () {
                self.showError();
            }
        });
    },

    showError: function() {
        this.contentNode
            .html(loc('Error retreiving user data'));
        this.mouseOver();
    },

    showUserInfo: function(html) {
        var self = this;
        this.contentNode.append(html);
        this.person = new Person({
            id: this.id,
            best_full_name: this.popup.find('.fn').text(),
            email: this.popup.find('.email').text()
        });
        var followLink = this.person.createFollowLink();
        if (followLink) {
            $('<div></div>')
                .addClass('follow')
                .append(
                    $('<ul></ul>').append($('<li></li>').append(followLink))
                )
                .appendTo(this.contentNode);
        }

        // min-height: 62px
        if ($.browser.msie) {
            if (this.contentNode.height() < 65) this.contentNode.height(65);
        }
        
        this.mouseOver();
    },

    displayAvatar: function() {
        if (!this.popup) {
            this.createPopup();
            var user_id = $(this.node).attr('userid');
            this.getUserInfo(user_id);
        }
        else {
            this.show();
        }
    },

    show: function() {
        var offset = $(this.node).offset();

        // Check if the avatar is more than half of the way down the page
        var winOffset = $.browser.msie ? document.documentElement.scrollTop 
                                       : window.pageYOffset;
        if ((offset.top - winOffset) > ($(window).height() / 2)) {
            this.popup
                .removeClass('underneath')
                .css('top', offset.top - this.popup.height() - 20);
        }
        else {
            this.popup
                .addClass('underneath')
                .css('top', offset.top + $(this.node).height());
        }

        this.popup.css('left', offset.left - 43 ).fadeIn();
    },

    hide: function() {
        if (this.popup) this.popup.fadeOut();
    }

};

$(function(){
    $('.person.authorized').each(function() { new Avatar(this) });
});

})(jQuery);
