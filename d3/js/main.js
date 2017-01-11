var ddb = "dat" + "/" + window.dd_base;
var ddt = ddb   + "/" + window.dd_this;

var nodes = graph_nodes(ddb + "/" + "nodes.csv");
var links = graph_links(ddb + "/" + "links.csv");



if (window.graph_only) {	
	var cluster = graph_noclu(ddb + "/" + "node-cluster.csv");
} else {	
	var nlmap   = graph_nlmap(ddb + "/" + "node-links.json");
	var vmean   = vi_mean(ddt     + "/" + "v-mean.csv");
	var imean   = vi_mean(ddt     + "/" + "i-mean.csv", get_column(ddb  + "/" + "links.csv",
								       "is_ohl_ugl",
								       "section_name",
								       true));
	var ampex   = abc_col(ddt     + "/" + "ampex.csv");
}



$(document).ready(
	function() {
		// 1. The coordinate system I've used is explained in https://bl.ocks.org/mbostock/3019563
		// 2. All dimensions are in pixels unless specified otherwise
		
		var outer_height = 900;
		var outer_width  = 900;
		var margin       = {top: 20, right: 20, bottom: 20, left: 20};
		var padding      = {top: 60, right: 60, bottom: 60, left: 60};

		var inner_height = outer_height - margin["top"]   - margin["bottom"];
		var inner_width  = outer_width  - margin["left"]  - margin["right"];

		var height       = inner_height - padding["top"]  - padding["bottom"];
		var width        = inner_width  - padding["left"] - padding["right"];
		
		
		
		var x = {},
		    y = {};
		
		var cx = d3.scaleLinear()
			    .domain(extent_of(nodes, "x"))
			    .range([0, width]);
		
		var cy = d3.scaleLinear()
			    .domain(extent_of(nodes, "y"))
			    .range([height, 0]); // As the origin is the top-left corner, and not bottom-left.
		
		for (var i = 0; i < nodes.length; i++) {
			x[nodes[i]["name"]] = cx(nodes[i]["x"]);
			y[nodes[i]["name"]] = cy(nodes[i]["y"]);
		}
		
		
		
		if (window.graph_only) {
			var clucol = d3.scaleOrdinal()
				    .domain(d3.range(1, window.max_clusters+1))
				    .range(d3.schemePaired);
		} else {
			var sw     = {},
			    s      = {},
			    r      = {},
			    fill   = {};
			
			var colors = ["#0000ff",
				      "#5a00ed",
				      "#7f00d9",
				      "#9b00c2",
				      "#b100aa",
				      "#c40090",
				      "#d50076",
				      "#e50057",
				      "#f30035",
				      "#ff0000"]; // Generated using https://gka.github.io/palettes/
			
			var stroke_width = d3.scaleQuantize()
				    .domain(d3.extent(flatten_object(imean, ["mA", "mB", "mC"], d3.mean)))
				    .range([2, 4, 6, 8, 10, 12, 14, 16, 18, 20]); // Whole: anti-aliasing friendly; Even: "r" friendly.
			
			for (var k in imean) {
				sw[k] = stroke_width(apply_h(imean[k], ["mA", "mB", "mC"], d3.mean));
			}
			
			var stroke = d3.scaleQuantize()
				    .domain([0, 1])
				    .range(colors);
			
			for (var k in ampex) {
				s[k] = stroke(apply_h(ampex[k], ["a", "b", "c"], d3.max));
			}
			
			for (var k in nlmap) {
				r[k] = apply_h(sw, nlmap[k], d3.max) / 2;
				if (!r[k]) {
					r[k] = 1;
				}

				var ciof = [];
				for (var i = 0; i < nlmap[k].length; i++) {
					ciof.push(colors.indexOf(s[nlmap[k][i]]));
				}
				fill[k] = colors[d3.max(ciof)];
			}
		}
		
		
		
		var svg = d3.select("#svg")
			    .attr("height", outer_height)
			    .attr("width",  outer_width)
			    .append("g") // (g: "grouping" element for an svg -- http://tutorials.jenkov.com/svg/g-element.html)
			    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

		var Graph = svg.append("g")
			    .attr("transform", "translate(" + padding.left + "," + padding.top + ")");
		
		
		
		if (!window.graph_only) {			
			var tooltip = d3.tip()
				    .attr("class", "tooltip")
				    .html(function(data) {
					    var id      = data[0];
					    var values  = data[1];
					    var units   = data[2];
					    var tooltip = "<div style='padding-bottom:3px'>ID: " + id + "</div>";
					    var info;
					    if (info = display_phase_info("a", values["mA"], values["aA"], units)) {
						    tooltip += "<div>" + info + "</div>";
					    }
					    if (info = display_phase_info("b", values["mB"], values["aB"], units)) {
						    tooltip += "<div>" + info + "</div>";
					    }
					    if (info = display_phase_info("c", values["mC"], values["aC"], units)) {
						    tooltip += "<div>" + info + "</div>";
					    }
					    return tooltip;
				    });
			
			Graph.call(tooltip);
		}
		
		
		
		var edges = Graph.selectAll(".edge")
			    .data(links)
			    .enter()
			    .append("line")
			    .attr("class", "edge")
			    .attr("x1", function(h) { return x[h["from_node_name"]]; }) // h: hash
			    .attr("y1", function(h) { return y[h["from_node_name"]]; })
			    .attr("x2", function(h) { return x[h["to_node_name"]]; })
			    .attr("y2", function(h) { return y[h["to_node_name"]]; })
			    .style("stroke-width", function(h) {
				    if (window.graph_only) {
					    return 2;
				    } else {
					    return sw[h["section_name"]];
				    }})
			    .style("stroke", function(h) {
				    if (window.graph_only) {
					    return "#cccccc";
				    } else {
					    return s[h["section_name"]];
				    }})
			    .on("mouseover", function(h) {
				    if (!window.graph_only) {
					    return tooltip.show([h["section_name"], imean[h["section_name"]], "A"]);
				    }})
			    .on("mouseout", function() {
				    if (!window.graph_only) {
					    return tooltip.hide();
				    }});
		
		
		
		var vertices = Graph.selectAll(".vertex")
			    .data(nodes)
			    .enter()
			    .append("circle")
			    .attr("class", "vertex")
			    .attr("cx", function(h) { return x[h["name"]]; })
			    .attr("cy", function(h) { return y[h["name"]]; })
			    .attr("r", function(h) {
				    if (window.graph_only) {
					    if (h["flag"]) {
						    return 1;
					    } else {
						    return 4;
					    }
				    } else {
					    return r[h["name"]];
				    }})
			    .attr("fill", function(h) {
				    if (window.graph_only) {
					    if (h["flag"]) {
						    return "#cccccc";
					    } else {
						    return clucol(cluster[h["name"]]);
					    }
				    } else {
					    return fill[h["name"]];
				    }})
			    .on("mouseover", function(h) {
				    if (!window.graph_only) {
					    return tooltip.show([h["name"], vmean[h["name"]], "V"]);
				    }})
			    .on("mouseout", function() {
				    if (!window.graph_only) {
					    return tooltip.hide();
				    }});
		
		
		
		if (!window.graph_only) {
			var lx0,
			    ly0;

			if (window.legend_position == "top-left") {
				lx0 = padding.left;
				ly0 = padding.top;
			} else if (window.legend_position == "top-right") {
				lx0 = 0.90 * width;
				ly0 = padding.top;
			} else if (window.legend_position == "bottom-left") {
				lx0 = padding.left;
				ly0 = 0.81 * height;
			} else if (window.legend_position == "bottom-right") {
				lx0 = 0.90 * width;
				ly0 = 0.81 * height;
			} else {
			}
			
			var Legend = svg.append("g")
				    .attr("class", "legendQuant")
				    .attr("transform", "translate(" + lx0 + "," + ly0 + ")");

			// http://d3-legend.susielu.com/
			Legend.call(d3.legendColor()
				    .labelFormat(d3.format(".1f"))
				    .scale(stroke));
		}
	}
);
