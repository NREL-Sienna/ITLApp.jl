make_widget_options(items) = [Dict("label" => x, "value" => x) for x in items]

function make_table_columns(rows)
    isempty(rows) && return []
    columns = []
    for (name, val) in Dict(zip(names(first(rows)), first(rows)))
        if val isa AbstractString
            type = "text"
        elseif val isa Number
            type = "numeric"
        else
            error("Unsupported type: $(val): $(typeof(val))")
        end
        push!(columns, Dict("name" => name, "id" => name, "type" => type))
    end

    return columns
end

function insert_json_text_in_markdown(json_text)
    return """
    ```json
    $json_text
    ```
    """
end

get_json_text_from_markdown(x) = strip(replace(replace(x, "```json" => ""), "```" => ""))

function pm_branch_name_formatting(x, from_bus, to_bus)
    br_type = x["source_id"][1]
    if br_type in ["two-terminal dc", "vsc dc", "branch"]
        return  "$(get_name(from_bus))_"*"$(get_name(to_bus))~"*strip("$(x["source_id"][4])")
    else
        return "$(get_name(from_bus))_"*"$(get_name(to_bus))~"*strip("$(x["source_id"][5])")
    end
end

ismfile = endswith(".m");
israwfile = endswith(".raw");