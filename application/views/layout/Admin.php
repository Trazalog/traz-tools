<!DOCTYPE html>
<html>

<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <title>TRAZALOG | TOOLS</title>
    <!-- Tell the browser to be responsive to screen width -->
    <meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
    <!-- Bootstrap 3.3.7 -->
    <link rel="stylesheet" href="lib/bower_components/bootstrap/dist/css/bootstrap.min.css">
    <!-- Font Awesome -->
    <link rel="stylesheet" href="lib/bower_components/font-awesome/css/font-awesome.min.css">
    <!-- Ionicons -->
    <link rel="stylesheet" href="lib/bower_components/Ionicons/css/ionicons.min.css">
    <!-- Theme style -->
    <link rel="stylesheet" href="lib/dist/css/AdminLTE.min.css">
    <!-- css iconos redondos -->
    <link rel="stylesheet" href="lib/iconcurved.css">
    <!-- css tabla scroll dispositivo movil -->
    <link rel="stylesheet" href="lib/table-scroll.css">

    <!-- css sweetalert -->
    <link rel="stylesheet" href="lib/sweetalert/sweetalert.css">
    <!-- Estilos case image + vista previa -->
    <link rel="stylesheet" href="lib/imageForms/styleImgForm.css">
    
    <!-- AdminLTE Skins. Choose a skin from the css/skins
       folder instead of downloading all of them to reduce the load. -->
    <link rel="stylesheet" href="<?php echo base_url();?>lib/dist/css/skins/_all-skins.min.css">

    <link rel="stylesheet" href="<?php echo base_url();?>lib/plugins/datetimepicker/css/bootstrap-datetimepicker.min.css">

    <link rel="stylesheet"
        href="<?php echo base_url()?>lib/bower_components/datatables.net-bs/css/dataTables.bootstrap.min.css">

        <!-- Select2 -->
        <link rel="stylesheet" href="<?php echo base_url()?>lib/bower_components/select2/dist/css/select2.min.css">

        
    <link rel="stylesheet" href="<?php echo base_url() ?>lib/bower_components/select2/dist/css/boostrap.css">



    <link rel="stylesheet" href="<?php echo base_url()?>lib/plugins/bootstrap-wysihtml5/bootstrap3-wysihtml5.min.css">

    <link rel="stylesheet" href="<?php echo base_url()?>lib/bower_components/bootstrap-daterangepicker/daterangepicker.css">

    <!-- Bootstrap datetimepicker -->
    <link rel="stylesheet" href="<?php echo base_url();?>lib/plugins/datetimepicker/css/bootstrap-datetimepicker.min.css">

    <!-- iCheck for checkboxes and radio inputs -->
    <link rel="stylesheet" href="<?php echo base_url();?>lib/plugins/iCheck/all.css">

    <link rel="stylesheet" href="<?php echo base_url();?>lib/bootstrapValidator/bootstrapValidator.min.css" />

    <!-- alertifyjs -->

    <link rel="stylesheet" href="<?php  echo base_url();?>lib/alertify/css/alertify.css">
    <link rel="stylesheet" href="<?php  echo base_url();?>lib/alertify/css/themes/bootstrap.css">

    <!-- animate.css -->

    <link rel="stylesheet" href="<?php  echo base_url();?>lib/animate/animate.css">

    <!-- Google Font -->
    <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Source+Sans+Pro:300,400,600,700,300italic,400italic,600italic">
    <link rel="stylesheet" href="<?php echo base_url() ?>lib/swal/dist/sweetalert2.min.css">
    <link rel="stylesheet" href="<?php echo base_url() ?>lib\timepicker\jquery.timepicker.min.css">

    <link href='<?php  echo base_url();?>assets/fullcalendar/lib/main.min.css' rel='stylesheet' />

    <!-- Lupa imagenes -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/magnify/2.3.3/css/magnify.css" integrity="sha512-JxBFHHd+xyHl++SdVJYCCgxGPJKCTTaqndOl/n12qI73hgj7PuGuYDUcCgtdSHTeXSHCtW4us4Qmv+xwPqKVjQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />

    <style>
        .mr-2{
            margin-right: 5px;
        }

        .oculto {
            display: none;
        }

        .trazalog:after {
            /*content: "\A TOOLS";*/
            content: " TOOLS";
            font-size: 12px;
            /*white-space: pre-line;*/
            
        }  

        .calendar {
            max-width: 1100px;
            margin: 0 auto;
        }

        .panel-primary>.panel-heading {
        color: #fff;
        background-color: #dd4b39 !important;
        border-color: #dd4b39 !important;
        }   

    </style>


    <?php $this->load->view('layout/general_scripts')?>

</head>

<?php $this->load->view('layout/wait') ?>

<body class="hold-transition skin-red sidebar-mini"></body>
<div class="wrapper">

    <header class="main-header">
        <!-- Logo -->
         <!-- Logo -->
        <!-- <a href="#"  class="logo"> -->
        <!-- mini logo for sidebar mini 50x50 pixels -->
        <!--    <span class="logo-mini"><strong><?php /*echo MNOM */?></strong></span>-->
		<!--				<span class="logo-lg" onclick="linkTo();"><b><?php /*echo NOM*/ ?></b></span>-->
        <!-- </span> -->
        <!--</a> -->
        <!-- Header Navbar: style can be found in header.less -->


        <a href="<?php echo base_url() ?>"  class="logo">
            <!-- </span> -->
            <img src="<?php echo base_url() ?>imagenes/trazalog/07ded14d.png" alt="Trazalog Tools" class="brand-image img-circle" style="width: 34px; height: auto !important;">
            <span class="trazalog">TRAZALOG </span>
            <!-- <span class="">TOOLS</strong></span> -->
            <!-- </span> -->
        </a>
        <!-- Header Navbar: style can be found in header.less -->
        <nav class="navbar navbar-static-top">
            <!-- Sidebar toggle button-->
            <a href="#" class="sidebar-toggle" data-toggle="push-menu" role="button">
                <span class="sr-only">Toggle navigation</span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
            </a>

            <?php

            	$this->load->view('layout/perfil');

            ?>


        </nav>
    </header>
    <!-- Left side column. contains the logo and sidebar -->
    <aside class="main-sidebar">
        <!-- sidebar: style can be found in sidebar.less -->
        <section class="sidebar" style="height: auto;">
            <?php echo $menu ?>
        </section>
        <!-- /.sidebar -->
    </aside>

    <!-- Content Wrapper. Contains page content -->
    <div class="content-wrapper">
        <!-- Content Header (Page header) -->
        <section id="content" class="content">



        </section>
        <!-- /.content -->
    </div>
    <!-- /.content-wrapper -->

    <footer class="main-footer">
        <div class="pull-right hidden-xs">
            <i style="cursor: pointer;" onclick="modalDetailVersion();"><strong>Versión </strong> <?php echo  ApplicationVersion::getVerision(); ?></i> 
        </div>
        <strong>Copyright &copy; 2021 <a href="">Trazalog</a>.</strong> All rights
        reserved.
    </footer>
    <?php $this->load->view('layout/modal_generico') ?>
    <!-- Control Sidebar -->
    <aside class="control-sidebar control-sidebar-dark">
        <!-- Create the tabs -->
        <ul class="nav nav-tabs nav-justified control-sidebar-tabs">
            <li><a href="#control-sidebar-home-tab" data-toggle="tab"><em class="fa fa-home"></em></a></li>
            <li><a href="#control-sidebar-settings-tab" data-toggle="tab"><em class="fa fa-gears"></em></a></li>
        </ul>
        <!-- Tab panes -->
        <div class="tab-content">
            <!-- Home tab content -->
            <div class="tab-pane" id="control-sidebar-home-tab">
                <h3 class="control-sidebar-heading">Recent Activity</h3>
                <ul class="control-sidebar-menu">
                    <li>
                        <a href="javascript:void(0)">
                            <em class="menu-icon fa fa-birthday-cake bg-red"></em>

                            <div class="menu-info">
                                <h4 class="control-sidebar-subheading">Langdon's Birthday</h4>

                                <p>Will be 23 on April 24th</p>
                            </div>
                        </a>
                    </li>
                    <li>
                        <a href="javascript:void(0)">
                            <em class="menu-icon fa fa-user bg-yellow"></em>

                            <div class="menu-info">
                                <h4 class="control-sidebar-subheading">Frodo Updated His Profile</h4>

                                <p>New phone +1(800)555-1234</p>
                            </div>
                        </a>
                    </li>
                    <li>
                        <a href="javascript:void(0)">
                            <em class="menu-icon fa fa-envelope-o bg-light-blue"></em>

                            <div class="menu-info">
                                <h4 class="control-sidebar-subheading">Nora Joined Mailing List</h4>

                                <p>nora@example.com</p>
                            </div>
                        </a>
                    </li>
                    <li>
                        <a href="javascript:void(0)">
                            <em class="menu-icon fa fa-file-code-o bg-green"></em>

                            <div class="menu-info">
                                <h4 class="control-sidebar-subheading">Cron Job 254 Executed</h4>

                                <p>Execution time 5 seconds</p>
                            </div>
                        </a>
                    </li>
                </ul>
                <!-- /.control-sidebar-menu -->

                <h3 class="control-sidebar-heading">Tasks Progress</h3>
                <ul class="control-sidebar-menu">
                    <li>
                        <a href="javascript:void(0)">
                            <h4 class="control-sidebar-subheading">
                                Custom Template Design
                                <span class="label label-danger pull-right">70%</span>
                            </h4>

                            <div class="progress progress-xxs">
                                <div class="progress-bar progress-bar-danger" style="width: 70%"></div>
                            </div>
                        </a>
                    </li>
                    <li>
                        <a href="javascript:void(0)">
                            <h4 class="control-sidebar-subheading">
                                Update Resume
                                <span class="label label-success pull-right">95%</span>
                            </h4>

                            <div class="progress progress-xxs">
                                <div class="progress-bar progress-bar-success" style="width: 95%"></div>
                            </div>
                        </a>
                    </li>
                    <li>
                        <a href="javascript:void(0)">
                            <h4 class="control-sidebar-subheading">
                                Laravel Integration
                                <span class="label label-warning pull-right">50%</span>
                            </h4>

                            <div class="progress progress-xxs">
                                <div class="progress-bar progress-bar-warning" style="width: 50%"></div>
                            </div>
                        </a>
                    </li>
                    <li>
                        <a href="javascript:void(0)">
                            <h4 class="control-sidebar-subheading">
                                Back End Framework
                                <span class="label label-primary pull-right">68%</span>
                            </h4>

                            <div class="progress progress-xxs">
                                <div class="progress-bar progress-bar-primary" style="width: 68%"></div>
                            </div>
                        </a>
                    </li>
                </ul>
                <!-- /.control-sidebar-menu -->

            </div>
            <!-- /.tab-pane -->
            <!-- Stats tab content -->
            <div class="tab-pane" id="control-sidebar-stats-tab">Stats Tab Content</div>
            <!-- /.tab-pane -->
            <!-- Settings tab content -->
            <div class="tab-pane" id="control-sidebar-settings-tab">
                <form method="post">
                    <h3 class="control-sidebar-heading">General Settings</h3>

                    <div class="form-group">
                        <label class="control-sidebar-subheading">
                            Report panel usage
                            <input type="checkbox" class="pull-right" checked>
                        </label>

                        <p>
                            Some information about this general settings option
                        </p>
                    </div>
                    <!-- /.form-group -->

                    <div class="form-group">
                        <label class="control-sidebar-subheading">
                            Allow mail redirect
                            <input type="checkbox" class="pull-right" checked>
                        </label>

                        <p>
                            Other sets of options are available
                        </p>
                    </div>
                    <!-- /.form-group -->

                    <div class="form-group">
                        <label class="control-sidebar-subheading">
                            Expose author name in posts
                            <input type="checkbox" class="pull-right" checked>
                        </label>

                        <p>
                            Allow the user to show his name in blog posts
                        </p>
                    </div>
                    <!-- /.form-group -->

                    <h3 class="control-sidebar-heading">Chat Settings</h3>

                    <div class="form-group">
                        <label class="control-sidebar-subheading">
                            Show me as online
                            <input type="checkbox" class="pull-right" checked>
                        </label>
                    </div>
                    <!-- /.form-group -->

                    <div class="form-group">
                        <label class="control-sidebar-subheading">
                            Turn off notifications
                            <input type="checkbox" class="pull-right">
                        </label>
                    </div>
                    <!-- /.form-group -->

                    <div class="form-group">
                        <label class="control-sidebar-subheading">
                            Delete chat history
                            <a href="javascript:void(0)" class="text-red pull-right"><em class="fa fa-trash-o"></em></a>
                        </label>
                    </div>
                    <!-- /.form-group -->
                </form>
            </div>
            <!-- /.tab-pane -->
        </div>
    </aside>
    <!-- /.control-sidebar -->
    <!-- Add the sidebar's background. This div must be placed
       immediately after the control sidebar -->
    <div class="control-sidebar-bg"></div>
</div>
<!-- ./wrapper -->


<!--_______ MODAL ______-->
<div class="modal" id="modalGitVersion">
    <div class="modal-dialog">
        <!-- modal-content -->
        <div class="modal-content">
            
            <!-- /.modal-body -->
            <div class="modal-body ">
                <?php
                    //echo  ApplicationVersion::getLastVersions();
                ?>
                <div id='calendar'></div>
			</div> 
            <!-- /.modal-body -->

            <!-- modal-footer -->
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">Aceptar</button>
            </div>
            <!-- modal-footer -->

        </div>
        <!-- /.modal-content -->
    </div>
</div>
<!-- /.modal -->




<script>

function modalDetailVersion(){

    $("#modalGitVersion").modal('show');

    //

    cargarCalendar();
}

function cargarCalendar(){

    var tagsLastCommits = <?php echo ApplicationVersion::getLastVersions(); ?>;
    /*console.log(tagsLastCommits);*/

    let lastCommits = tagsLastCommits[0].split("\n");  
    console.log(lastCommits);

    var dataCalendar = [];

    lastCommits.forEach(function callback(elemento, indice, array) {  
        /*console.log("Elemento: "+elemento, indice);*/
        tagElemento = elemento.split(" ");
        /*console.log(tagElemento[0]+" "+tagElemento[4]+" "+tagElemento[5]);*/
        if (typeof(tagElemento[4]) != "undefined" && typeof(tagElemento[5]) != "undefined"){
            dataCalendar[indice] = {
                title : tagElemento[4] +" "+tagElemento[5],
                start : tagElemento[0],
                end : tagElemento[0]  

            }
        }

    });
    /*console.log(dataCalendar);*/
    var data = dataCalendar.filter(Boolean);
    var events = JSON.stringify(data);
    console.log(events);


    var initialLocaleCode = 'es';
    var calendarEl = document.getElementById('calendar');

    var calendar = new FullCalendar.Calendar(calendarEl, {
      headerToolbar: {
        left: 'prev,next',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,listMonth'
      },
      initialDate: new Date(),
      locale: initialLocaleCode,
      navLinks: true, 
      businessHours: true, 
      selectable: true,
      events: $.parseJSON(events)  
    });

    calendar.render();
  }


linkTo('<?php echo DEF_VIEW ?>');

function collapse(e) {
    e = $(e).closest('.box');

    if (e.hasClass('collapsed-box')) {
        $(e).removeClass('collapsed-box');
    } else {
        $(e).addClass('collapsed-box');
    }

}


/* Abre cuadro cargando ajax */
function WaitingOpen(texto) {
    if (texto == '' || texto == null) {
        $('#waitingText').html('Cargando ...');
    } else {
        $('#waitingText').html(texto);
    }
    $('#waiting').fadeIn('slow');
}
/* Cierra cuadro cargando ajax */
function WaitingClose() {
    $('#waiting').fadeOut('slow');
}

/* Abre cuadro cargando ajax */
function wo(texto) {
   WaitingOpen(texto);
}
/* Cierra cuadro cargando ajax */
function wc() {
    WaitingClose();
}
</script>

<script src='<?php  echo base_url();?>assets/fullcalendar/lib/main.js'></script>
<script src='<?php  echo base_url();?>assets/fullcalendar/lib/locales-all.js'></script>

</body>

</html>