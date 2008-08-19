(function($) {

var t = new Test.Visual();

t.plan(1);
// t.plan(2);

t.runTests = function() {
    var $avatar = t.$("#st-listview-form tr.oddRow td:eq(1) img.avatar");
    t.is(
        $avatar.size(),
        1,
        "There are user avatars in recent changes listview"
    );

// TODO Need to get this one to pass in the Harness:
//
//     t.is(
//         t.$.curCSS( $avatar.get(0), "float")
//         "none",
//         "Make sure it's not floated to left or right."
//     );

    t.iframe.contentWindow.scrollTo(0, 200);
};

t.open_iframe("/admin/index.cgi?action=recent_changes");

})(jQuery);
