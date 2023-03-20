$(document).ready(function () {

    // all custom jQuery will go here
    $("#firstbutton").click(function () {
        $.ajax({
            url: "http://localhost:30005", success: function (result) {
                $("#firstbutton").toggleClass("btn-primary:focus");
                }
        });
    });
    $("#secondbutton").click(function () {
        $.ajax({
            url: "http://localhost:30006", success: function (result) {
                $("#secondbutton").toggleClass("btn-primary:focus");
            }
        });
    });    
});