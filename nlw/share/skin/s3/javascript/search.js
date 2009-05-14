(function ($) {

    $(function() {

        $('.searchSelect').change(function () {
            var $form = $(this).parent('form');
            $("option:selected",this).each(function() {
                var scope = $(this).hasClass('scopeStar') ? '*' : '_';
                $('.searchScope',$form).val(scope);
            });
        });

    });

})(jQuery);
