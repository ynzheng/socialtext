(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        t.open_iframe("/?profile", t.nextStep());
    },
            
    function() { 
        var rss_link = t.$('iframe[src*=local:people:profile_activities]').get(0).contentWindow.document.getElementById('rss_link');

        t.is(
            rss_link.getAttribute('target'),
            '_top',
            "[RSS Feed] link opens in parent window, not a child window"
        );

        t.endAsync();
    }
]);

})(jQuery);
