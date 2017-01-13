function graph_nodes(file) {
	var aoh = []; // aoh: array-of-hashes
	d3.csv(file, function(df) { // df: data-frame
		for (var i = 0; i < df.length; i++) {
			aoh[i] = {
				name  :  df[i]["name"],
				x     : +df[i]["x"], // The unary + converts string-numbers to javascript's numeric type
				y     : +df[i]["y"],
				flag  : +df[i]["is_loaded"]
			};
		}
	});
	return aoh;
}



function graph_links(file) {
	var aoh = [];
	d3.csv(file, function(df) {
		for (var i = 0; i < df.length; i++) {
			aoh[i] = {
				section_name    :  df[i]["section_name"],
				from_node_name  : +df[i]["from_node_name"],
				to_node_name    : +df[i]["to_node_name"],
				flag            : +df[i]["is_ohl_ugl"]
			};
		}
	});
	return aoh;
}



function graph_nlmap(file) {
	var hoa = {}; // hoa: hash-of-arrays
	d3.json(file, function(json) {
		for (var i = 0; i < json.length; i++) {
			hoa[json[i]["node"]] = json[i]["links"];
		}
		
	});
	return hoa;
}



function graph_noclu(file) {
	var hash = {};
	d3.csv(file, function(df) {
		for (var i = 0; i < df.length; i++) {
			hash[df[i]["name"]] = +df[i]["cluster"];
		}
	});
	return hash;
}



function get_column(file,
		    column,     // The name of the column whose data is of interest.
		    index,      // The name of the index column.
		    numerate) { // If the data is to be converted to numerical type, pass any truthy value.
	var hash  = {};
	d3.csv(file, function(df) {
		for (var i = 0; i < df.length; i++) {
			if (numerate) {
				hash[df[i][index]] = +df[i][column];
			} else {
				hash[df[i][index]] =  df[i][column];
			}
		}
	});
	return hash;
}



function vi_mean(file,
		 flag) { // The "selector" hash for the data-frame contained in the file.
	var flag_on = (typeof flag !== "undefined") ? true : false;
	var hoh     = {}; // hoh: hash-of-hashes
	d3.csv(file, function(df) {
		for (var i = 0; i < df.length; i++) {
			var mA,
			    aA,
			    mB,
			    aB,
			    mC,
			    aC;
			if (flag_on && flag[df[i]["name"]] === 0) {
				mA = aA = mB = aB = mC = aC = undefined;
			} else {
				if ((df[i]["mA"] === undefined) || (df[i]["mA"] === "NA") || (+df[i]["mA"] === 0)) {
					mA = undefined;
				} else {
					mA = sprintf("%.1f", +df[i]["mA"]);
				}
				if ((df[i]["aA"] === undefined) || (df[i]["aA"] === "NA") || (+df[i]["aA"] === 0 && +df[i]["mA"] === 0)) {
					aA = undefined;
				} else {
					aA = sprintf("%.1f", +df[i]["aA"]);
				}
				if ((df[i]["mB"] === undefined) || (df[i]["mB"] === "NA") || (+df[i]["mB"] === 0)) {
					mB = undefined;
				} else {
					mB = sprintf("%.1f", +df[i]["mB"]);
				}
				if ((df[i]["aB"] === undefined) || (df[i]["aB"] === "NA") || (+df[i]["aB"] === 0 && +df[i]["mB"] === 0)) {
					aB = undefined;
				} else {
					aB = sprintf("%.1f", +df[i]["aB"]);
				}
				if ((df[i]["mC"] === undefined) || (df[i]["mC"] === "NA") || (+df[i]["mC"] === 0)) {
					mC = undefined;
				} else {
					mC = sprintf("%.1f", +df[i]["mC"]);
				}
				if ((df[i]["aC"] === undefined) || (df[i]["aC"] === "NA") || (+df[i]["aC"] === 0 && +df[i]["mC"] === 0)) {
					aC = undefined;
				} else {
					aC = sprintf("%.1f", +df[i]["aC"]);
				}
			}
			hoh[df[i]["name"]] = {
				mA : mA,
				aA : aA,
				mB : mB,
				aB : aB,
				mC : mC,
				aC : aC
			};
		}
	});
	return hoh;
}



function abc_col(file,   // COLUMNS: name, a, b, c
		 flag) { // The "selector" hash for the data-frame contained in the file.
	var flag_on = (typeof flag !== "undefined") ? true : false;
	var hoh     = {}; // hoh: hash-of-hashes
	d3.csv(file, function(df) {
		for (var i = 0; i < df.length; i++) {
			var a,
			    b,
			    c;
			if (flag_on && flag[df[i]["name"]] === 0) {
				a = b = c = undefined;
			} else {
				if ((df[i]["a"] === undefined) || (df[i]["a"] === "NA")) {
					a = undefined;
				} else {
					a = +df[i]["a"];
				}
				if ((df[i]["b"] === undefined) || (df[i]["b"] === "NA")) {
					b = undefined;
				} else {
					b = +df[i]["b"];
				}
				if ((df[i]["c"] === undefined) || (df[i]["c"] === "NA")) {
					c = undefined;
				} else {
					c = +df[i]["c"];
				}
			}
			hoh[df[i]["name"]] = {
				a : a,
				b : b,
				c : c
			};
		}
	});
	return hoh;
}
