var t = new Test.Wikiwyg();

t.filters({
    text: ['wikitext_to_html', 'html_to_wikitext']
});

t.plan(1);

t.run_is('before', 'after');

/*
=== {bz: 2476} - Before and After should be identical
--- before
^Header

one
two
three
four

--- after
^Header

one
two
three
four

*/
