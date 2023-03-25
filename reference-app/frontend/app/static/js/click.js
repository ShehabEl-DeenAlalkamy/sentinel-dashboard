$(document).ready(function () {
    // all custom jQuery will go here
    $("#firstbutton").click(function () {
        $.ajax({
            url: `${BACKEND_SVC_BASE_URL}`,
            success: function (result) {
                $("#firstbutton").toggleClass("btn-primary:focus");
            },
        });
    });
    $("#secondbutton").click(function () {
        $.ajax({
            url: `${TRIAL_SVC_BASE_URL}`,
            success: function (result) {
                $("#secondbutton").toggleClass("btn-primary:focus");
            },
        });
    });
});
