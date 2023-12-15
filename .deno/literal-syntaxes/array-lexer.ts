import {compile} from 'https://deno.land/x/moo@0.5.1-deno.2/mod.ts';

// build lexer
export const lexer = compile({
    valueString: {
        match: /"(?:\\["\\]|[^\n"\\])*"/,
        value: x => JSON.parse(x),
        type: x => 'value',
    },
    valueRaw: {
        match: /[^\s,\{\}"](?:[^,\{\}"]*[^\s,\{\}"])?/,
        type: () => 'value',
    },
    comma: ',',
    space: { match: /[\s\t\n\v\f\r]+/, lineBreaks: true, },
    start_list: '{',
    end_list: '}',
});

lexer.next = (next => () => {
    let tok;
    while ((tok = next.call(lexer)) && (tok.type === 'space')) {
    }
    return tok;
})(lexer.next);

export const lexerAny: any = lexer;