var map; 

var MAPBOX_TOKEN = "pk.eyJ1IjoieW1nYzE5IiwiYSI6ImNseWZ3ODc1MTAzbDQyanBvZTN6OTg2Y3gifQ.CzsGY4FHHyoiV8YgGK65bA";
var SPECIFICATION = "https://corymccartan.github.io/neighborhood-survey/assets/tokyo.json";
var ADJACENCY_GRAPH = "https://corymccartan.github.io/neighborhood-survey/assets/tokyo_graph.json";

Qualtrics.SurveyEngine.addOnload(function() {
    this.disableNextButton();

    map = window.MapDraw("#ns__container", {
        token: MAPBOX_TOKEN,
        url: SPECIFICATION,
        graph: ADJACENCY_GRAPH,
        errors: showError,
        allowProceed: (function(allow) {
            if (allow) this.enableNextButton();
            else this.disableNextButton();
        }).bind(this)
    });
});

Qualtrics.SurveyEngine.addOnReady(function() {
    function addressSearch() {
        var box = jQuery("#ns__address-box")
        var query = box.val();
        if (query.trim() == "") return;

        Qualtrics.SurveyEngine.setEmbeddedData("home_address", query.trim());
        map.loadAddress(query, box[0]);
    }

    jQuery("#ns__address-go").on("click", addressSearch);
    jQuery("#ns__address-box").on("keydown", function(e) {
        if (e.keyCode == 13) {
            e.preventDefault();
            addressSearch();
        }
    });
});

Qualtrics.SurveyEngine.addOnPageSubmit(function() {
    Qualtrics.SurveyEngine.setEmbeddedData("neighborhood", map.getNeighborhood());
});

