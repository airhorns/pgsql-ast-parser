@lexer lexerAny
@include "base.ne"

functions_statements -> create_func | do_stm

array_of[EXP] -> $EXP (%comma $EXP {% last %}):* {% ([head, tail]) => {
    return [unwrap(head), ...(tail.map(unwrap) || [])];
} %}

# https://www.postgresql.org/docs/13/sql-createfunction.html
create_func -> %kw_create
                (%kw_or kw_replace):?
                kw_function
                qname
                (lparen array_of[func_argdef]:? rparen {% get(1) %})
                func_returns:?
                %kw_as
                (%codeblock {% x => unwrap(x).value %} | string)
                func_spec:* {% x => {
                    const specs: any = {};
                    for (const s of x[8]) {
                        Object.assign(specs, s);
                    }
                    return track(x, {
                        type: 'create function',
                        ...x[1] && {orReplace: true},
                        name: x[3],
                        ...x[5] && {returns: unwrap(x[5])},
                        arguments: x[4] ?? [],
                        code: unwrap(x[7]),
                        ...specs,
                    });
                } %}


func_argdef -> func_argopts:?
                    data_type {% x => track(x, {
                        type: x[1],
                        ...x[0],
                    }) %}

func_argopts -> func_argmod word:? {% x => track(x, {
                        mode: toStr(x[0]),
                        ...x[1] && { name: toStr(x[1]) },
                    }) %}
                | word {% (x, rej) => {
                    const name = toStr(x);
                    if (name === 'out' || name === 'inout' || name === 'variadic') {
                        return rej; // avoid ambiguous syntax
                    }
                    return {name}
                } %}

func_argmod -> %kw_in | kw_out | kw_inout | kw_variadic

func_spec -> kw_language word {% x => track(x, { language: unbox(last(x)) }) %}
         | func_purity {% x => track(x, {purity: toStr(x)}) %}
         | %kw_not:? (word {% kw('leakproof') %}) {% x => track(x, { leakproof: !x[0] })%}
         | func_spec_nil {% unwrap %}


func_spec_nil -> (word {%kw('called')%}) oninp {% () => ({ onNullInput: 'call' }) %}
                | (word {%kw('returns')%}) %kw_null oninp {% () => ({ onNullInput: 'null' }) %}
                | (word {%kw('strict')%})  {% () => ({ onNullInput: 'strict' }) %}

func_purity -> word {%kw('immutable')%}
            |  word {%kw('stable')%}
            |  word {%kw('volatile')%}

oninp -> %kw_on %kw_null (word {%kw('input')%})

func_returns -> kw_returns data_type {% last %}
                | kw_returns %kw_table lparen array_of[func_ret_table_col] rparen {% x => track(x, {
                    kind: 'table',
                    columns: x[3],
                }) %}

func_ret_table_col -> word data_type {% x => track(x, {name: unbox(x[0]), type: x[1]}) %}

# https://www.postgresql.org/docs/13/sql-do.html
do_stm -> %kw_do (kw_language word {% last %}):? %codeblock {% x => track(x, {
    type: 'do',
    ...x[1] && { language: toStr(x[1])},
    code: x[2].value,
}) %}
