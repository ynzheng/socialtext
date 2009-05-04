var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('wikitext');

/* Test
=== Wikitext from bug description
--- wikitext
^Header

one
two
three
four

*/
