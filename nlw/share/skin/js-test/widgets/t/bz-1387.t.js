(function($) {

var t = new Test.Visual();

t.plan(1);


t.runAsync([
    function() {
        t.setup_one_widget('Recent Conversations', t.nextStep());
    },

    function() { 
        t.is(
            t.$('.widgetHeaderTitleBox:first span').attr('title'),
            'Recent Conversations',
            'Header text should hover as titletext'
        );

        t.endAsync();
    }
]);

})(jQuery);
