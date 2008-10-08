(function($) {

var t = new Test.Visual();

t.plan(1);

t.runAsync([
    function() {
        var v = "VeryLongLineVeryLongLine"
              + "VeryLongLineVeryLongLine"
              + "VeryLongLine ";

        t.put_page({
            workspace: 'admin',
            page_name: "bz_1471",
            content: v + v + v + v + v + "\n\n"
                   + ".pre\n"
                   + v + v + v + v + "\n"
                   + ".pre\n",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?bz_1471", t.nextStep());
    },
            
    function() { 
        t.is(
            t.$('#contentLeft').offset().top,
            t.$('#contentRight').offset().top,
            "Mixed .pre and non-.pre long lines should not drop contentRight"
        );

        t.endAsync();
    }
]);

})(jQuery);
