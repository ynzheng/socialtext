jQuery('#st-email-lightbox').remove(); //remove this line after

var ST = ST || {};
ST.Email = function () {
    this.restURL = '/data/workspaces/' + Socialtext.wiki_id;
};

var proto = ST.Email.prototype = { firstAdd: true };


proto.clearEmails= function () {
    if (this.firstAdd) {
        jQuery('#email_dest option').remove();
        jQuery('#email_dest').removeClass("lookahead-prompt");
    }
};
proto.clearHelp = function () {
    this.clearEmails();
    this.firstAdd = false;
};

proto.show = function () {
    var self = this;
    if (!jQuery('#st-email-lightbox').size()) {
        Socialtext.loc = loc;
        Socialtext.full_uri = location.href.replace(/#.*$/, '').replace(/index\.cgi\?/, '?');

        jQuery('<div class="lightbox" id="st-email-lightbox" />')
            .appendTo('body')
            .html( Jemplate.process('email.tt2', Socialtext) );

        jQuery('#email_page_add_one').click(function () {
            jQuery(this).val('');
        });

        jQuery('#email_add').click(function () {
            self.clearHelp();
            jQuery('#email_source option:selected').appendTo('#email_dest');
        });

        jQuery('#email_remove').click(function () {
            jQuery('#email_dest option:selected').remove();
        });

        jQuery('#email_all').click(function () {
            jQuery.getJSON('/data/workspaces/' + Socialtext.wiki_id + '/users?limit=9999999', function (data) {
                self.clearHelp();
                for (var i=0; i<data.length; i++) {
                    jQuery('<option />')
                        .html(data[i].email)
                        .appendTo('#email_dest');
                }
            });
        });

        jQuery('#email_none').click(function () {
            jQuery('#email_dest option').remove();
        });

        jQuery('#email_recipient')
            .lookahead({
                url: '/data/workspaces/' + Socialtext.wiki_id + '/users',
                linkText: function (user) {
                    return user.best_full_name
                         + ' <' + user.email_address +'>';
                },
                displayAs: function (item) {
                    return item.title;
                },
                onAccept: function(id, item) {
                    jQuery('#email_recipient').blur();
                    jQuery('#email_add').click();
                }
            })
            .focus(function() {
                if ($(this).hasClass('lookahead-prompt')) {
                    $(this).val("");
                    $(this).removeClass("lookahead-prompt");
                }
            });

        jQuery('#email_add').click(function () {
            var val = jQuery('#email_recipient').val();
            var email = val.replace(/^.*<(.*)>$/, '$1');
            if (!val) {
                return false;
            }
            else if (!Email.Page.check_address(val)) {
                alert(loc('"[_1]" is not a valid email address.', val))
                jQuery('#email_page_add_one').focus();
                return false;
            }
            else {
                jQuery('#email_recipient').val('').focus();
                var matches = jQuery.grep(
                    jQuery('#email_dest option'),
                    function(opt) {
                        var val = opt.value.replace(/^.*<(.*)>$/, '$1');
                        return val == email;
                    }
                );
                if (!matches.length) {
                    jQuery('<option />')
                        .val(email).text(val).appendTo('#email_dest');
                }
                return false;
            }
        });


        jQuery('#st-email-lightbox-form').submit(function () {
            var val = jQuery('#email_recipient').val();
            var send_copy_checked = jQuery('input[name="email_page_send_copy"]').is(":checked");
            if ((val.length > 0) && (!self.firstAdd)) {
                jQuery('#email_add').click();
            }
            if ((jQuery('#email_dest').get(0).length <= 0 || self.firstAdd) && (!send_copy_checked)) {
                alert(loc('Error: To send email, you must specify a recipient.'));
                return false;
            }
            
            jQuery('#email_send').parent('li').addClass('disabled');
            jQuery('#email_dest option').attr('selected', true);
           
            self.clearEmails();
            var data = jQuery(this).serialize();
            jQuery.ajax({
                type: 'post',
                url: Page.cgiUrl(),
                data: data,
                success: function (data) {
                    jQuery.hideLightbox();
                },
                error: function() {
                    alert(loc('Error: Failed to send email.'));
                    jQuery('#email_send').parent('li').removeClass('disabled');
                    jQuery('#email_dest option').attr('selected', false);
                }
            })
            return false;
        });

    }
    else {
        jQuery('#email_dest option').remove();
    }

    $('#st-email-lightbox .submit').unbind('click').click(function () {
        $(this).parents('form').submit();
    });

    jQuery.showLightbox({
        content: '#st-email-lightbox',
        close: '#email_cancel',
        width: '580px',
        callback: function() {
            jQuery('input[name="email_page_subject"]').select().focus();
            jQuery('#email_send').parent('li').removeClass('disabled');
            this.firstAdd = true;
        }
    });
}
