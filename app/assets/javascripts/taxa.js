jQuery(function() {
    if (document.getElementById("taxonomy_tree") != null) {
        $.ajax({
            type: "GET",
            contentType: "application/json; charset=utf-8",
            url: 'taxa/taxonomy_tree',
            dataType: 'json',
            processData: false,
            success: function (data) {
                drawTaxonomy(data[0]);
            },
            error: function (_result) {
                console.error("Error getting data.");
            }
        });
    }

    $('#taxon_parent_name').autocomplete({
        source: $('#taxon_parent_name').data('autocomplete-source')});

    $('#taxon_project_ids').chosen({
        allow_single_deselect: true,
        no_results_text: 'No results matched'
    });

    $('#taxon_search').autocomplete({
        source: $('#taxon_search').data('autocomplete-source')});
});

// Main function to draw and set up the visualization, once we have the data.
function drawTaxonomy(data) {
    var parentDiv = document.getElementById("taxonomy_tree");

    // Set the dimensions and margins of the diagram
    var width = parentDiv.clientWidth - 17,
        height = 710,
        margin = { left: 50, top: 10, bottom: 10, right: 50 },
        nodeRadius = 10,
        scale = 1;

    // Append the SVG object to the parent div
    var svg = d3.select('#taxonomy_tree')
        .append("svg")
        .attr('id', 'taxa_svg')
        .attr('width', "100%")
        .attr('height', height)
        .attr("preserveAspectRatio", "xMinYMin slice")
        .attr("viewBox", "0 0 " + width + " " + height)
        .classed("svg-content", true);

    // Appends a 'group' element to 'svg' and moves it to the top left margin
    var mainGroup = svg.append('g')
        .attr('transform', 'translate(' + margin.left + ',' + margin.top + ')');

    // Enable zoom & pan
    var zoom = d3.zoom()
        .on("zoom", function() {
            mainGroup.attr("transform", d3.event.transform)
        });

    svg.call(zoom);

    var taxon_text = d3.select('#taxon_info').append('p').attr('id', 'taxon_text');

    var i = 0,
        duration = 750,
        root;

    // // Declares a tree layout and assigns the size
    var treemap = d3.tree().size([width, height]);

    // Assigns the data to a hierarchy using parent-child relationships
    root = d3.hierarchy(data, function(d) {
        return d.children;
    });
    root.x0 = height / 2;
    root.y0 = 0;

    root.loaded = true;

    update(root);

    centerNode(root);

    // Setup buttons
    disableButton($("#edit_taxon"), "Please select a taxon first");

    // Button to reset zoom and reset tree to top left
    d3.select("#reset_tree_pos")
        .on("click", function() {
            zoom.transform(svg, d3.zoomIdentity.translate(margin.left, margin.top).scale(scale));
        });

    // Button to reset zoom and center root node
    d3.select("#center_root")
        .on("click", function() {
            centerNode(root);
        });

    d3.select('#start_search')
        .on("click", function() {
            var taxon_name = document.getElementById('taxon_search').value;

            $.ajax({
                type: "GET",
                contentType: "application/json; charset=utf-8",
                url: 'taxa/find_ancestry?taxon_name=' + taxon_name,
                dataType: 'text',
                processData: false,
                success: function (ancestry) {
                    var ancestor_ids = ancestry.split('/');
                    open_path(root, ancestor_ids);
                },
                error: function (_result) {
                    console.error("Error getting data.");
                }
            });
        });

    function update(source) {
        var levelHeight = [1];
        var childCount = function(level, n) {
            if (n.children && n.children.length > 0) {
                if (levelHeight.length <= level + 1) levelHeight.push(0);

                levelHeight[level + 1] += n.children.length;
                n.children.forEach(function(d) {
                    childCount(level + 1, d);
                });
            }
        };
        childCount(0, root);
        var newHeight = d3.max(levelHeight) === 2 ? 2 * 50 + (25 * levelHeight.length) : d3.max(levelHeight) * 50; // Account for diagonals in height calculation

        treemap = treemap.size([newHeight, width]);

        treeData = treemap(root);

        // Compute the new tree layout.
        var nodes = treeData.descendants(),
            links = treeData.descendants().slice(1);

        // Normalize for fixed-depth.
        nodes.forEach(function(d) { d.y = d.depth * 180 });

        // ****************** Nodes section ***************************

        // Update the nodes...
        var node = mainGroup.selectAll('g.node')
            .data(nodes, function(d) {
                return d.id || (d.id = ++i);
            });

        // Enter any new nodes at the parent's previous position.
        var nodeEnter = node.enter().append('g')
            .attr('class', 'node')
            .attr("transform", function(_d) {
                return "translate(" + source.y0 + "," + source.x0 + ")";
            })
            .on("mouseover", function(d) {
                d3.select(this).style("cursor", "pointer");
            })
            .on("mouseout", function(d) {
                d3.select(this).style("cursor", "default");
            });

        // Add circle for the nodes
        nodeEnter.append('circle')
            .attr("r", nodeRadius)
            .attr('id', function(d) { return "node_" + d.data.id })
            .classed("closed", function(d) { return d._children })
            .style("fill", function(d) {
                return d.data.has_children ? "lightgrey" : "#fff";
            })
            .attr("stroke", '#616161')
            .attr("stroke-width", '3')
            .on('click', click);

        nodeEnter.append('g')
            .append('text')
            .text(function (d) {
                return d.data.scientific_name;
            })
            .attr('y', function (d) {
                return d.data.has_children ?
                    nodeRadius * 2 : 0;
            })
            .attr('x', function (d) {
                return d.data.has_children ?
                    0 : nodeRadius * 1.5;
            })
            .attr("dy", '.35em')
            .attr("text-anchor", function (d) {
                return d.data.has_children ?
                    'middle' : 'left';
            })
            .attr("fill-opacity", 1)
            .style('font', '14px sans-serif')
            .on('click', function(d) {
                // Display taxon info in top left div
                var text = "<b>Scientific name:</b> " + htmlSafe(d.data.scientific_name) + "<br>";
                if (d.data.taxonomic_rank) text += "<b>Taxonomic rank</b>: " + htmlSafe(d.data.taxonomic_rank) + "<br>";
                if (d.data.synonym) text += "<b>Synonym</b>: " + htmlSafe(d.data.synonym) + "<br>";
                if (d.data.common_name) text += "<b>Common name:</b> " + htmlSafe(d.data.common_name) + "<br>";
                if (d.data.author) text += "<b>Author:</b> " + htmlSafe(d.data.author) + "<br>";
                if (d.data.comment) text += "<b>Comment:</b> " + htmlSafe(d.data.comment) + "<br>";
                taxon_text.html(text);

                // Set correct taxon edit link and enable button
                var taxon_link = d3.select('#edit_taxon').attr('href').replace(/(.*\/)(\d+)(\/.*)/, "$1" + d.data.id + "$3");
                d3.select('#edit_taxon').attr('href', taxon_link);
                enableButton($('#edit_taxon'), 'Edit in a new tab');

                // Display list of specimen associated with this taxon
                display_specimen_Data(d);
            });

        // UPDATE
        var nodeUpdate = nodeEnter.merge(node);

        // Transition to the proper position for the node
        nodeUpdate.transition()
            .duration(duration)
            .attr("transform", function(d) {
                return "translate(" + d.y + "," + d.x + ")";
            });

        // Update the node attributes and style
        nodeUpdate.select('circle.node')
            .attr("r", nodeRadius)
            .style("fill", function(d) {
                return d.data.has_children ? "lightgrey" : "#fff";
            })
            .attr('cursor', 'pointer');

        // Remove any exiting nodes
        var nodeExit = node.exit().transition()
            .duration(duration)
            .attr("transform", function(_d) {
                return "translate(" + source.y + "," + source.x + ")";
            })
            .remove();

        // On exit reduce the node circles size to 0
        nodeExit.select('circle')
            .attr('r', 1e-6);

        // On exit reduce the opacity of text labels
        nodeExit.select('text')
            .style('fill-opacity', 1e-6);

        // ****************** links section ***************************

        // Update the links...
        var link = mainGroup.selectAll('path.link')
            .data(links, function(d) { return d.id; });

        // Enter any new links at the parent's previous position.
        var linkEnter = link.enter()
            .insert('path', "g")
            .attr("class", "link")
            .attr("fill", 'none')
            .attr("stroke", 'lightgrey')
            .attr("stroke-width", '2px')
            .attr('d', function(_d){
                var o = {
                    x: source.x0,
                    y: source.y0
                };
                return diagonal(o, o)
            });

        // UPDATE
        var linkUpdate = linkEnter.merge(link);

        // Transition back to the parent element position
        linkUpdate.transition()
            .duration(duration)
            .attr('d', function(d) {
                return diagonal(d, d.parent)
            });

        // Remove any exiting links
        link.exit().transition()
            .duration(duration)
            .attr('d', function(_d) {
                var o = {x: source.x, y: source.y};
                return diagonal(o, o)
            })
            .remove();

        // Store the old positions for transition.
        nodes.forEach(function(d){
            d.x0 = d.x;
            d.y0 = d.y;
        });
    }

    // Creates a curved (diagonal) path from parent to the child nodes
    function diagonal(s, d) {
        path = `M ${s.y} ${s.x}
            C ${(s.y + d.y) / 2} ${s.x},
              ${(s.y + d.y) / 2} ${d.x},
              ${d.y} ${d.x}`;

        return path
    }

    // Toggle children on click.
    function click(d) {
        var circle = d3.select(this);

        var promise = get_child_data(d);

        if(promise !== undefined) circle.classed("spinner",true);

        promise !== undefined ? $.when(promise).done(function() {
            circle.classed("spinner",false);
            toggle(d);
        }.bind(this)) : toggle(d);
    }

    function centerNode(source) {
        x = -source.y0;
        y = -source.x0;
        x = x  + $("#taxa_svg").width() / 2; // Use current width of SVG
        y = y + height / 2;

        d3.select('g').transition()
            .duration(duration)
            .attr("transform", "translate(" + x + "," + y + ")scale(" + scale + ")");
        zoom.transform(svg, d3.zoomIdentity.translate(x, y).scale(scale));
    }

    //	Toggle children on click.
    function toggle(d) {
        if (d.children) {
            d._children = d.children;
            d.children = null;
        } else {
            d.children = d._children;
            d._children = null;
        }
        update(d);
        centerNode(d);
    }

    function get_child_data(d) {
        if(d.loaded !== undefined)
            return;

        var newNodes = [];

        var promise = $.ajax({
            url: "taxa/taxonomy_tree?parent_id=" + d.data.id,
            dataType: 'json',
            type: 'GET',
            cache: false,
            success: function(responseJson) {
                if(responseJson.length === 0)
                    return;

                responseJson.forEach(function(element) {
                    var newNode = d3.hierarchy(element);
                    newNode.depth = d.depth + 1;
                    newNode.height = d.height - 1;
                    newNode.parent = d;

                    newNodes.push(newNode);
                });

                if (d.children) {
                    newNodes.forEach(function(node) {
                        d.children.push(node);
                        d.data.children.push(node.data);
                    })
                }
                else {
                    d._children = [];
                    d.data._children = [];

                    newNodes.forEach(function(node) {
                        d._children.push(node);
                        d.data._children.push(node.data);
                    })
                }

                d.loaded = true;
            }
        });

        return promise; //return a promise if async. requests
    }

    function display_specimen_Data(d) {
        $.ajax({
            url: "taxa/" + d.data.id + "/associated_specimen",
            dataType: 'json',
            type: 'GET',
            cache: false,
            success: function(data) {
                var ul = "<ul class=\"list-group list-group-flush\">";
                data.forEach(function(element) {
                    ul += "<li class=\"list-group-item\"><a href='individuals/" + element.id + "/edit' target='_blank'>" + element.specimen_id + "</a></li>";
                });
                ul += "</ul>";

                d3.select('#specimen_list').html(ul);
            }
        });
    }

    function open_path(node, ancestor_ids) {
        //TODO: doesn't work anymore when called the second time
        //TODO: collapse all other nodes except path
        //TODO: maybe highlight path

        console.log(ancestor_ids);
        var ancestor_id = ancestor_ids.shift();

        if (parseInt(node.data.id) === parseInt(ancestor_id)) {
            // Avoid endless loop when node is already opened
            if (ancestor_ids.length !== 1) {
                open_path(node, ancestor_ids);
            }
            else {
                centerNode(node); //TODO: doesn't work
            }
        }
        else {
            node.children.forEach(function (child_node) {
                if (parseInt(child_node.data.id) === parseInt(ancestor_id)) {
                    if (!child_node.children) {
                        var node_circle = d3.select("#node_" + ancestor_id);

                        var promise = get_child_data(child_node);

                        if (promise !== undefined) node_circle.classed("spinner", true);

                        promise !== undefined ? $.when(promise).done(function () {
                            node_circle.classed("spinner", false);
                            toggle(child_node);
                            open_path(child_node, ancestor_ids);
                        }.bind(node_circle)) : toggle(child_node);
                    }
                }
            });


        }
    }
}
