(function($) {

var t = new Test.Visual();

t.plan(1);

var tag = "bz_1199_" + Math.random();
t.runAsync([
    function() {
        t.open_iframe("/admin/?action=display;add_tag="+tag+";page_name=Untitled Page#edit", t.nextStep(5000));
    },
            
    function() { 
        t.$('#st-newpage-pagename-edit').val('['+tag+']');
        t.$('#st-mode-wikitext-button').click();
        t.callNextStep(1500);
    },

    function() { 
        t.$('#wikiwyg_wikitext_textarea').val("{tag_list: "+tag+"}");
        t.$('#st-mode-wysiwyg-button').click();
        t.callNextStep(5000);
    },

    function() { 
        t.$('#st-save-button-link').click();
        t.callNextStep(5000);
    },

    function() { 
        t.is(
            t.$('div.wafl_items a').text(),
            '['+tag+']',
            "No extra paren on tag_list wafl"
        );

        t.endAsync();
    }
]);

})(jQuery);
