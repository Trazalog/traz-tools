var site = null;
var backSite = null;

function linkTo(link = null) {
    $('body').css('padding-right', '');
    wo();
    $("#content").empty();
    if (link != null) {
        $("#content").load(link, function() {
            wc();
        });
        backSite = site;
        site = link;

        return;
    }

    $("#content").load(site, function() {
        wc();
    });

}

function back() {
    linkTo(backSite);
}


$(".menu .link").click(function() {
    if (this.dataset.link == "") {
        linkTo("Admin/nopage");
    } else {

        linkTo(this.dataset.link);
    }
});

var html_wbox = '<div class="overlay wbox" style="background:rgba(0, 0, 0, 0.5) !important;"><i class="fa fa-refresh fa-spin"></i></div>';
var s_wbox = false;

function wbox(id = false) {

    if (!id) { $(s_wbox).find('.wbox').remove() } else {
        if ($(id).find('.overlay').length == 0) {
            $(id).append(html_wbox);
            s_wbox = id;
        }
    }
}

function wo(texto = null) {
    if (texto == "" || texto == null) {
        $("#waitingText").html("Cargando ...");
    } else {
        $("#waitingText").html(texto);
    }
    $("#waiting").fadeIn("slow");
}

function wc() {
    $("#waiting").fadeOut("slow");
}

var bak_icon = null;
var wait_icon = '<i class="fa fa-spinner fa-spin mr-1"></i>';

function wb(e) {
    const ban = $(e).prop("disabled");

    if (ban) {
        if ($(e).hasClass("fa")) {
            $(e).removeClass().addClass(bak_icon);
        } else {
            $(e).find("i").remove();
            $(e).prepend("<i class='" + bak_icon + "'></i>");
        }
    } else {
        if ($(e).hasClass("fa")) {
            bak_icon = $(e).attr("class");
            $(e).removeClass().addClass("fa fa-spinner fa-spin mr-1");
        } else {
            bak_icon = $(e).find("i").attr("class");
            $(e).find("i").remove();
            $(e).prepend(wait_icon);
        }
    }

    $(e).prop("disabled", !ban);
}

function reload(e = false, parametro = false) {
	debugger;
	if (e) {
        var link = false;

        if ($(e).hasClass("reload")) {
            link = $(e).attr("data-link");
        } else {
            e = $(e).closest(".reload");
            link = $(e).attr("data-link");
        }

        console.log('RELOAD: ' + link);
        if (!link) {
            console.log("Falla al recargar el contenido");
            return;
        }

        if($(e).closest('.w-box').length != 0){
            console.log('ban_1');
            $(e).closest('.box').append("<div class='overlay'><i class='fa fa-refresh fa-spin'></i></div>");
        }else{
            console.log('ban_2');
            $(e).html("Cargando...");
        }
        wo();
        $(e).load(link + (parametro ? "/" + parametro : ""), function() { $(e).closest('.box').find('.overlay').remove(); wc()});
    } else {
        return;
    }
}