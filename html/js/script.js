function $() {
	return document.querySelector.apply(document, arguments);
}

if (navigator.userAgent.indexOf("Xcode") != -1) {
	document.documentElement.classList.add("xcode");
}

var jumpTo = $("#jump-to");

if (jumpTo) {
	jumpTo.addEventListener("change", function(e) {
		location.hash = this.options[this.selectedIndex].value;
	});
}

function hashChanged() {
	if (/^#\/\/api\//.test(location.hash)) {
		var element = document.querySelector("a[name='" + location.hash.substring(1) + "']");

		if (!element) {
			return;
		}

		element = element.parentNode;

		element.classList.remove("hide");
		fixScrollPosition(element);
	}
}

function fixScrollPosition(element) {
	var scrollTop = element.offsetTop - 150;
	document.documentElement.scrollTop = scrollTop;
	document.body.scrollTop = scrollTop;
}

[].forEach.call(document.querySelectorAll(".section-method"), function(element) {
	element.classList.add("hide");

	element.querySelector(".method-title a").addEventListener("click", function(e) {
		var info = element.querySelector(".method-info"),
			infoContainer = element.querySelector(".method-info-container");

		element.classList.add("animating");
		info.style.height = (infoContainer.clientHeight + 40) + "px";
		fixScrollPosition(element);
		element.classList.toggle("hide");

		setTimeout(function() {
			element.classList.remove("animating");
			info.style.height = "auto";
		}, 300);
	});
});

window.addEventListener("hashchange", hashChanged);
hashChanged();
