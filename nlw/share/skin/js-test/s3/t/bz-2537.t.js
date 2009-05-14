var t = new Test.Visual();
var name = t.gensym();

t.plan(1);

var content = '^ Fnord\n\n';

content += '.html\n\n';
content += '<table>\n\n';

for (var i = 0 ; i < 100 ; i++) {
    content += '<tr><td><img src="/data/wafl/' + i + '.png" /></td></tr>\n';
}

content += '</table>\n\n';
content += '.html\n\n';

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: name,
            content: content,
            tags: ['template'],
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe(
	    '/admin/?action=display;template=' + name
	    + ';page_type=wiki;page_name=Untitled%20Page#edit'
	    , t.nextStep()
	)
    },

    t.doRichtextEdit(),

    function() {
	t.$('#st-newpage-pagename-edit').val(t.gensym());
	t.callNextStep();
    },

    t.doSavePage(),

    function() { 
        t.is( t.$('h1#fnord').length, 1, "Templates with large number of images can be created" );
        t.endAsync();
    }
]);
