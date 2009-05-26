(function($) {

var t = new Test.Visual();

t.plan(1);

if (jQuery.browser.msie)
    t.skipAll("Skipping this insanity on IE for now");

t.runAsync([
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        t.setup_one_widget(
            {
                name: 'LabPixies ToDo',
                noPoll: true
            },
            t.nextStep()
        );
    },

    function(widget) {
        t.like(
            widget.$('body').html(),
            /Type new task here/,
            "TODO widget initialized correctly"
        );

        t.endAsync();
    }
]);

})(jQuery);
