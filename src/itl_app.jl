using Dash
using DataFrames
using PowerSystems
using InterfaceLimits
using HiGHS

const ITL = InterfaceLimits
const DEFAULT_UNITS = "unknown"

include("utils.jl")

mutable struct SystemData
    system::Union{Nothing, System}
end

SystemData() = SystemData(nothing)
get_system(data::SystemData) = data.system

function get_system_units(sys)
    return lowercase(get_units_base(sys))
end

function make_datatable(itl_results)
    columns = make_table_columns(itl_results)
    return (
        dash_datatable(
            id = "itl_results",
            columns = columns,
            data = Dict.(pairs.(eachrow(itl_results))),
            editable = false,
            filter_action = "native",
            sort_action = "native",
            row_selectable = "multi",
            selected_rows = [],
            style_table = Dict("height" => 400),
            style_data = Dict(
                "width" => "100px",
                "minWidth" => "100px",
                "maxWidth" => "100px",
                "overflow" => "hidden",
                "textOverflow" => "ellipsis",
            ),
        ),
        itl_results,
    )
end

system_tab = dcc_tab(
    label = "System",
    children = [
        html_div(
            [
                html_div(
                    [
                        html_br(),
                        html_h1("System View"),
                        html_div([
                            dcc_input(
                                id = "system_text",
                                value = "Enter the path of a system file",
                                type = "text",
                                style = Dict("width" => "50%", "margin-left" => "10px"),
                            ),
                            html_button(
                                "Load System",
                                id = "load_button",
                                n_clicks = 0,
                                style = Dict("margin-left" => "10px"),
                            ),
                        ]),
                        html_br(),
                        html_div([
                            html_div(
                                [
                                    html_div(
                                        [
                                            html_h5("Loaded system"),
                                            dcc_textarea(
                                                readOnly = true,
                                                value = "None",
                                                style = Dict(
                                                    "width" => "100%",
                                                    "height" => 100,
                                                    "margin-left" => "10px",
                                                ),
                                                id = "load_description",
                                            ),
                                        ],
                                        className = "column",
                                    ),
                                    html_div(
                                        [
                                            html_h5("Select units base"),
                                            dcc_radioitems(
                                                id = "units_radio",
                                                options = [
                                                    (
                                                        label = DEFAULT_UNITS,
                                                        value = DEFAULT_UNITS,
                                                        disabled = true,
                                                    ),
                                                    (
                                                        label = "device_base",
                                                        value = "device_base",
                                                    ),
                                                    (
                                                        label = "natural_units",
                                                        value = "natural_units",
                                                    ),
                                                    (
                                                        label = "system_base",
                                                        value = "system_base",
                                                    ),
                                                ],
                                                value = DEFAULT_UNITS,
                                                style = Dict("margin-left" => "3%"),
                                            ),
                                        ],
                                        className = "column",
                                    ),
                                ],
                                className = "row",
                            ),
                        ]),
                        html_div([
                            dcc_loading(
                                id = "loading_system",
                                type = "default",
                                children = [html_div(id = "loading_system_output")],
                            ),
                        ]),
                        html_br(),
                        html_div(
                            [
                                html_div(
                                    [
                                        html_h5("Selet an interface"),
                                        dcc_radioitems(
                                            id = "interface_radio",
                                            options = [],
                                            value = "",
                                            style = Dict("margin-left" => "3%"),
                                        ),
                                    ],
                                    className = "column",
                                ),
                                html_div(
                                    [
                                        html_h5("Enforce generator limits"),
                                        dcc_radioitems(
                                            id = "enforce_gen_limits_radio",
                                            options = [
                                                    (
                                                        label = "true",
                                                        value = true,
                                                    ),
                                                    (
                                                        label = "false",
                                                        value = false,
                                                    ),
                                                ],
                                            value = false,
                                            style = Dict("margin-left" => "3%"),
                                        ),
                                    ],
                                    className = "column",
                                ),
                                html_div(
                                    [
                                        html_h5("Enforce load distribution factors"),
                                        dcc_radioitems(
                                            id = "enforce_ldf_radio",
                                            options = [
                                                    (
                                                        label = "true",
                                                        value = true,
                                                    ),
                                                    (
                                                        label = "false",
                                                        value = false,
                                                    ),
                                                ],
                                            value = false,
                                            style = Dict("margin-left" => "3%"),
                                        ),
                                    ],
                                    className = "column",
                                ),
                                html_div(
                                    [
                                        html_h5("Enforce N-1 security"),
                                        dcc_radioitems(
                                            id = "enforce_security_radio",
                                            options = [
                                                    (
                                                        label = "true",
                                                        value = true,
                                                    ),
                                                    (
                                                        label = "false",
                                                        value = false,
                                                    ),
                                                ],
                                            value = false,
                                            style = Dict("margin-left" => "3%"),
                                        ),
                                    ],
                                    className = "column",
                                ),
                                html_button(
                                    "Calculate Transfer Limits",
                                    id = "calculate_button",
                                    n_clicks = 0,
                                    style = Dict("margin-left" => "10px"),
                                ),
                            ],
                            className = "row",
                        ),
                    ],
                    className = "column",
                ),
                html_div(
                    [
                        html_div([
                            html_br(),
                            html_img(src = joinpath("assets", "logo.png"), height = "250"),
                        ],),
                        html_div([
                            html_button(
                                dcc_link(
                                    children = ["PowerSystems.jl Docs"],
                                    href = "https://nrel-Sienna.github.io/PowerSystems.jl/stable/",
                                    target = "PowerSystems.jl Docs",
                                ),
                                id = "docs_button",
                                n_clicks = 0,
                                style = Dict("margin-top" => "10px"),
                            ),
                        ]),
                    ],
                    className = "column",
                    style = Dict("textAlign" => "center"),
                ),
            ],
            className = "row",
        ),
        html_br(),
        # TODO: delay displaying this table until the results are calculated
        html_h3("Interface Transfer Limit Results"),
        html_div(
            [
                dash_datatable(id = "itl_results"),
                html_div(id = "itl_results_container"),
            ],
            style = Dict("color" => "black"),
        ),
    ],
)

# Note: This is only setup to support one worker. We would need to implement a backend
# process that manages a store and provides responses to each Dash worker. The code in this
# file would not be able to use any PSY functionality. There would have to be API calls
# to retrieve the data from the backend process.
g_data = SystemData()
get_system() = get_system(g_data)
app = dash(assets_folder = joinpath(@__DIR__, "assets"))
app.layout = html_div() do
    html_div([
        html_div(
            id = "app-page-header",
            children = [
                html_a(
                    id = "dashbio-logo",
                    href = "https://www.energy.gov/oe/north-american-energy-resilience-model-naerm",
                    target = "_blank",
                    children = [
                        html_img(src = joinpath("assets", "DOE_OE_NAERM_LockUp_FullColor-01.png")),
                    ],
                ),
                html_h2("ITLApp.jl"),
                html_a(
                    id = "gh-link",
                    children = ["View on GitHub"],
                    href = "https://github.com/NREL-Sienna/ITLApp.jl",
                    target = "_blank",
                    style = Dict("color" => "#d6d6d6", "border" => "solid 1px #d6d6d6"),
                ),
                html_img(src = joinpath("assets", "GitHub-Mark-Light-64px.png")),
            ],
            className = "app-page-header",
        ),
        html_div([
            dcc_tabs(
                [
                    dcc_tab(
                        label = "System",
                        children = [system_tab],
                        className = "custom-tab",
                        selected_className = "custom-tab--selected",
                    ),
                ],
                parent_className = "custom-tabs",
            ),
        ]),
    ])
end

callback!(
    app,
    Output("loading_system_output", "children"),
    Output("load_description", "value"),
    Output("units_radio", "value"),
    Output("interface_radio", "options"),
    Input("loading_system", "children"),
    Input("load_button", "n_clicks"),
    State("system_text", "value"),
    State("load_description", "value"),
) do loading_system, n_clicks, system_path, load_description
    n_clicks <= 0 && throw(PreventUpdate())
    
    system = 
    if (ismfile(system_path))
        System(system_path, time_series_read_only = true)
    elseif (israwfile(system_path))
        System(system_path, 
               bus_name_formatter = x->string(strip(x["name"])*"_"*string(x["index"])),
               load_name_formatter = x-> x["source_id"][1]*"_$(x["source_id"][2])~"*strip(x["source_id"][3]),
               branch_name_formatter = pm_branch_name_formatting, 
               time_series_read_only = true)
    else
        error("Unrecognised System format..")
    end

    g_data.system = system
    return (
        loading_system,
        "$system_path\n$(summary(system))",
        get_system_units(system),
        string.(collect(keys(ITL.find_interfaces(system)))),
    )
end

callback!(
    app,
    Output("interface_radio", "value"),
    Input("interface_radio", "options"),
) do available_options
    isnothing(get_system()) && throw(PreventUpdate())
    return ""
end

callback!(
    app,
    Output("itl_results_container", "children"),
    Input("units_radio", "value"),
    Input("interface_radio", "value"),
    Input("enforce_gen_limits_radio", "value"),
    Input("enforce_ldf_radio", "value"),
    Input("enforce_security_radio", "value"),
    Input("calculate_button", "n_clicks"),
) do units, ikey, gen_lims, ldf_lims, security, n_clicks_calculate
    n_clicks_calculate < 1 && throw(PreventUpdate())

    (units == "" || ikey == "") && throw(PreventUpdate())
    system = get_system()
    @assert !isnothing(system)
    @assert units != DEFAULT_UNITS
    if get_system_units(system) != units
        set_units_base_system!(system, units)
    end

    interfaces = ITL.find_interfaces(system)
    clean_key = Pair(String.(strip.(split(replace(ikey,  "\"" => ""), "=>")))...)
    iface = interfaces[clean_key]

    itl_results = find_interface_limits(
        system,
        optimizer_with_attributes(HiGHS.Optimizer),
        clean_key,
        iface,
        interfaces,
        enforce_gen_limits = gen_lims,
        enforce_load_distribution = ldf_lims,
        security = security,
    )
    table, results = make_datatable(itl_results)
    return table, string(nrow(results))
end

function run_itl_app(; port = 8050)
    @info("Navigate browser to: http://0.0.0.0:$port")
    if !isnothing(get(ENV, "SIENNA_DEBUG", nothing))
        run_server(app, "0.0.0.0", port, debug = true, dev_tools_hot_reload = true)
    else
        run_server(app, "0.0.0.0", port)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_itl_app()
end
