var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

if ( Wikiwyg.is_safari ) {
        t.skipAll("On Safari, we do not convert HTML to wikitext");
}
else {
    t.plan(1);
    t.run_is('html', 'text');
}

/* Test
=== Bold, italics and strikethrough in the TD level are correctly preserved
--- html
<div class="wiki">
<table border="1" class="formatter_table" style="border-collapse: collapse;">
<tbody><tr>
<td style="font-weight: bold">Bold</td>
<td style="font-style: italic">Italic</td>
<td style="text-decoration: line-through">Strikethrough</td>
</tr>
</tbody></table>
</div>

--- text
| *Bold* | _Italic_ | -Strikethrough- |

*/
