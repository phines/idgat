function flatten_object(hoh, keys, // hoh: hash-of-hashes; key(s): key(s), whose value(s) are of interest within each (un-nested) hash
			func) {    // Apply this function to the values within each hash, prior to flattening?
	var A = [];
	for (var K in hoh) {
		var a = [];
		for (var k = 0; k < keys.length; k++) {
			a.push(hoh[K][keys[k]]);
		}
		if (typeof func === "function") {
			A.push(func(a));
		} else {
			A.push(a);
		}
	}
	return [].concat.apply([], A); // See http://stackoverflow.com/a/10865042
}



function apply_h(hash, keys,
		 func,       // Apply this function to the values within each hash
		 undef) {    // The value to return if func(a) = undefined
	undef = (typeof undef === "undefined") ? undefined : undef;
	var a = [];
	for (var i = 0; i < keys.length; i++) {
		a.push(hash[keys[i]]);
	}
	var fa;
	if (typeof func === "function") {
		fa = func(a);
	} else {
		fa = undef;
	}
	return fa;
}



function extent_of(aoh, key) { // aoh: array-of-hashes; key: key, whose value is of interest within each (un-nested) hash
	var min = d3.min(aoh, function(h) { return h[key]; });
	var max = d3.max(aoh, function(h) { return h[key]; });
	return [min, max];
}



function display_phase_info(phase, // a | b | c
			    magnitude,
			    angle, // degrees
			    units) {
	if ((typeof magnitude !== "undefined") && (typeof angle !== "undefined")) {
		return(phase + ": " + magnitude + "\u2220" + angle + "\xB0 " + units);
	}
}
