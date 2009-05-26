(function($) {

var t = new Test.Visual();

t.plan(1);


t.runAsync([
    function() {
        $.ajax({
            url: "/?action=clear_widgets",
            async: false
        });
        t.open_iframe("/?action=gallery;type=dashboard", t.nextStep());
    },

    function () {
        t.open_iframe(
            t.$('a:contains(Recent Conversations)').attr('href').replace(
                /^\/*/, '/'
            ), t.nextStep()
        );
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
