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
                });
            this.updateFollowLink();
            return this.node;
        }
    },

    follow: function() {
        var self = this;
        jQuery.ajax({
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
        jQuery.ajax({
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

    fields: [
        [ {name:'best_full_name', wrap: '<b></b>'} ],
        [ {name:'position'}, {name:'company'}],
        [ {name:'location'} ],
        [ {name:'email'} ],
        [ {name:'work_phone', prefix:'work: '} ]
    ],

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
            .appendTo(this.node);
        $('<img/>')
            .attr('src', nlw_make_s3_path('/images/avatarPopupBottom'))
            .appendTo(this.popup);
    },

    getUserInfo: function(userid) {
        var self = this;
        $.ajax({
            url: '/data/people/' + userid,
            cache: false,
            dataType: 'json',
            success: function (data) {
                self.showUserInfo(data);
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

    showUserInfo: function(user) {
        var self = this;

        $('<img/>')
            .addClass('avatarPhoto')
            .attr('src', "/data/people/" + user.id + "/photo")
            .appendTo(this.contentNode);

        var $info = $('<div></div>')
            .addClass('userinfo')
            .appendTo(this.contentNode);

        $.each(this.fields, function() {
            var $div = $('<div></div>').appendTo($info);

            var added = 0;
            $.each(this, function() {
                var val = user[this.name];
                if (val) {
                    if (added++) $div.append(', ');
                    if (this.prefix) val = this.prefix + val;
                    $(this.wrap || '<span></span>').text(val).appendTo($div);
                }
            });
        });

        this.person = new Person(user);
        var followLink = this.person.createFollowLink();
        if (followLink) {
            $('<div></div>')
                .addClass('follow')
                .append(
                    $('<ul></ul>').append($('<li></li>').append(followLink))
                )
                .appendTo(this.contentNode);
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
        this.popup
            .css('top', offset.top - this.popup.height() - 20)
            .css('left', offset.left - 43 )
            .fadeIn();
    },

    hide: function() {
        if (this.popup) this.popup.fadeOut();
    }

};

$(function(){
    $('.person').each(function() { new Avatar(this) });
});

})(jQuery);
