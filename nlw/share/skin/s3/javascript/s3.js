(function ($) {

Page = {
    attachmentList: [],

    pageUrl: function (page_name) {
        if (!page_name) page_name = Socialtext.page_id;
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/pages/' + page_name;
    },

    cgiUrl: function () {
        return '/' + Socialtext.wiki_id + '/index.cgi';
    },

    refreshPageContent: function (force_update) {
        $.getJSON(this.pageUrl(), function (data) {
            var newRev = data.revision_id;
            var oldRev = Socialtext.revision_id;
            if ((oldRev < newRev) || force_update) {
                $.get(Page.pageUrl(), function (html) {
                    $('#st-page-content').html(html);
                    Socialtext.wikiwyg_variables.page.revision_id =
                        Socialtext.revision_id = newRev
                    $('#st-rewind-revision-count').html(newRev);
                });
            }
        });
    },

    tagUrl: function (tag) {
        return this.pageUrl() + '/tags/' + encodeURIComponent(tag);
    },

    attachmentUrl: function (attach_id) {
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/attachments/' + Socialtext.page_id + ':' + attach_id
    },

    refreshTags: function () {
        var tag_url = '?action=category_display;category=';
        $.getJSON( this.pageUrl() + '/tags', function (tags) {
            $('#st-tags-listing').html('');
            for (var i=0; i< tags.length; i++) {
                var tag = tags[i];
                $('#st-tags-listing').append(
                    $('<li>').append(
                        $('<a>')
                            .html(tag.name)
                            .attr('href', tag_url + tag.name),
                        ' ',
                        $('<a href="#">')
                            .html('[x]')
                            .attr('name', tag.name)
                            .bind('click', function () {
                                Page.delTag(this.name);
                            })
                    )
                )
            }
        });
    },

    refreshAttachments: function (cb) {
        Page.attachmentList = [];
        $.getJSON( this.pageUrl() + '/attachments', function (list) {
            $('#st-attachment-listing').html('');
            for (var i=0; i< list.length; i++) {
                var item = list[i];
                Page.attachmentList.push(item.name);
                $('#st-attachment-listing').append(
                    $('<li>').append(
                        $('<a>')
                            .html(item.name)
                            .attr('href', item.uri),
                        ' ',
                        $('<a href="#">')
                            .html('[x]')
                            .attr('name', item.uri)
                            .bind('click', function () {
                                Page.delAttachment(this.name)
                            })
                    )
                )
            }
            if (cb) cb();
        });
    },

    delTag: function (tag) {
        $.ajax({
            type: "DELETE",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
            }
        });
    },

    delAttachment: function (url) {
        $.ajax({
            type: "DELETE",
            url: url,
            complete: function () {
                Page.refreshAttachments();
                Page.refreshPageContent();
            }
        });
    },

    addTag: function (tag) {
        $.ajax({
            type: "PUT",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
                $('#st-tags-field').val('');
            }
        });
    }
};

var push_onload_function = function (fcn) { jQuery(fcn) }

$(function() {
    $('#st-page-boxes-toggle-link')
        .bind('click', function() {
            $('#st-page-boxes').toggle();
            var hidden = $('#st-page-boxes').is(':hidden');
            this.innerHTML = hidden ? 'show' : 'hide';
            Cookie.set('st-page-accessories', hidden ? 'hide' : 'show');
        });

    $('#st-tags-addlink')
        .bind('click', function () {
            $(this).hide();
            $('#st-tags-field')
                .val('')
                .show()
                .focus();
        })

    $('#st-tags-field')
        .blur(function () {
            setTimeout(function () {
                $('#st-tags-field').hide();
                $('#st-tags-addlink').show()
            }, 500);
        })
        .lookahead({
            url: '/data/workspaces/' + Socialtext.wiki_id + '/tags',
            linkText: function (i) {
                return [i.name, i.name];
            },
            onAccept: function (val) {
                Page.addTag(val);
            }
        });
            

    $('#st-tags-form')
        .bind('submit', function () {
            var tag = $('#st-tags-field').val();
            Page.addTag(tag);
            return false;
        });

    $('#st-attachments-uploadbutton').unbind('click').click(function () {
        $('#st-attachments-attach-list').html('').hide();
        $.showLightbox({
            content:'#st-attachments-attachinterface',
            close:'#st-attachments-attach-closebutton'
        });
        return false;
    });

    $('#st-attachments-attach-filename')
        .val('')
        .bind('change', function () {
            var filename = $(this).val();
            if (!filename) {
                $('#st-attachments-attach-uploadmessage').html(
                    loc("Please click browse and select a file to upload.")
                );
                return false;
            }

            var filename = filename.replace(/^.*\\|\/:/, '');

            if (encodeURIComponent(filename).length > 255 ) {
                $('#st-attachments-attach-uploadmessage').html(
                    loc("Filename is too long after URL encoding.")
                );
                return false;
            }

            $('#st-attachments-attach-uploadmessage').html(
                loc('Uploading [_1]...', filename.match(/[^\\\/]+$/))
            );

            $('#st-attachments-attach-formtarget')
                .unbind('load')
                .bind('load', function () {
                    $('#st-attachments-attach-uploadmessage').html(
                        loc('Upload Complete')
                    );
                    $('#st-attachments-attach-filename').attr(
                        'disabled', false
                    );
                    $('#st-attachments-attach-closebutton').attr(
                        'disabled', false
                    );
                    Page.refreshAttachments(function () {
                        $('#st-attachments-attach-list')
                            .show()
                            .html('')
                            .append(
                                $('<span>')
                                    .attr(
                                        'class',
                                        'st-attachments-attach-listlabel'
                                    )
                                    .html(
                                        loc('Uploaded files:') + 
                                        Page.attachmentList.join(', ')
                                    )
                            );
                    });
                    Page.refreshPageContent();
                });

            $('#st-attachments-attach-form').submit();
            $('#st-attachments-attach-closebutton').attr('disabled', true);
            $(this).attr('disabled', true);

            return false;
        });


    var editor_uri = nlw_make_s3_path('/javascript/socialtext-editor.js.gz')
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    var lightbox_uri = nlw_make_s3_path('/javascript/socialtext-lightbox.js.gz')
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    function get_lightbox (cb) {
        $.ajaxSettings.cache = true;
        $.getScript(lightbox_uri, cb);
        $.ajaxSettings.cache = false;
    }

    $("#st-comment-button-link").click(function () {
        get_lightbox(function () {
            var ge = new GuiEdit({
                oncomplete: function () {
                    Page.refreshPageContent()
                }
            });
            ge.show();
        });
        return false;
    });

    $(".weblog_comment").click(function () {
        var page_id = this.id.replace(/^comment_/,'');
        get_lightbox(function () {
            var ge = new GuiEdit({
                page_id: page_id,
                oncomplete: function () {
                    $.get(Page.pageUrl(page_id), function (html) {
                        $('#content_'+page_id).html(html);
                    });
                }
            });
            ge.show();
        });
        return false;
    });

    $("#st-pagetools-email").click(function () {
        get_lightbox(function () {
            var Email = new ST.Email;
            Email.show();
        });
        return false;
    });

    //index.cgi?action=duplicate_popup;page_name=[% page.id %]
    $("#st-pagetools-duplicate").click(function () {
        get_lightbox(function () {
            var move = new ST.Move;
            move.duplicateLightbox();
        });
        return false;
    });
    
    $("#st-pagetools-rename").click(function () {
        get_lightbox(function () {
            var move = new ST.Move;
            move.renameLightbox();
        });
        return false;
    });

    //index.cgi?action=copy_to_workspace_popup;page_name=[% page.id %]')
    $("#st-pagetools-copy").click(function () {
        get_lightbox(function () {
            var move = new ST.Move;
            move.copyLightbox();
        });
    });


    $("#st-pagetools-delete").click(function () {
        if (confirm(loc("Are you sure you want to delete this page?"))) {
            var page = Socialtext.page_id;
            document.location = "index.cgi?action=delete_page;page_name=" + page;
        }
        return false;
    });

    $("#st-edit-button-link,#st-edit-actions-below-fold-edit")
        .one("click", function () {
            $('#bootstrap-loader').show();
            $.ajaxSettings.cache = true;
            $.getScript(editor_uri);
            $.ajaxSettings.cache = false;
            $('<link>')
                .attr('href', nlw_make_s3_path('/css/wikiwyg.css'))
                .attr('rel', 'stylesheet')
                .attr('media', 'wikiwyg')
                .attr('type', 'text/css')
                .appendTo('head');
        });

    $('#st-listview-submit-pdfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a PDF."));
        }
        else {
            $('#st-listview-action').val('pdf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.pdf');
            $('#st-listview-form').submit();
        }
    });

    $('#st-listview-submit-rtfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a Word document."));
        }
        else {
            $('#st-listview-action').val('rtf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.rtf');
            $('#st-listview-form').submit();
        }
    });

    $('#st-listview-selectall').click(function () {
        $('input[type=checkbox]').attr('checked', this.checked);
    });

    $('#st-watchlist-indicator').click(function () {
        var self = this;
        if ($(this).hasClass('on')) {
            $.get(
                location.pathname + '?action=remove_from_watchlist'+
                ';page=' + Socialtext.page_id +
                ';_=' + (new Date()).getTime(),
                function () {
                    $(self).attr('title', loc('Watch this page'));
                    $(this).removeClass('on');
                }
            );
        }
        else {
            $.get(
                location.pathname + '?action=add_to_watchlist'+
                ';page=' + Socialtext.page_id +
                ';_=' + (new Date()).getTime(),
                function () {
                    $(self).attr('title', loc('Stop watching this page'));
                    $(this).addClass('on');
                }
            );
        }
    });

    if (Socialtext.new_page ||
        Socialtext.start_in_edit_mode ||
        location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            $("#st-edit-button-link").click();
        }, 500);
    }
});

})(jQuery);
