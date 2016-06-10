<?php
/* testing    */
# ChangeLog 2015-03-20
#   cgi-bin/update_queue_file.pl is run in the qd_pconsc_fe.pl 

require("class_template.php");

$tplObj = new tplSys("./");
$tplObj_refresh = new tplSys("./");
$tplObj->getFile( array('pconsc' => '/pconsc.html' ));
$tplObj_refresh->getFile( array('pconsc' => '/pconsc_refresh.html' ));
$isRefreshPage = 0;
$refresh_interval = "\"60\"";

# debug nanjiang, get basedir (where the php code is located)
#
$hostname_of_the_computer = `hostname` ;

# defining global variables =======================
$host = GetHostByName($_SERVER['REMOTE_ADDR']); 
$server_ip = $_SERVER['SERVER_ADDR'];
$http_host = $_SERVER['HTTP_HOST'];
$basedir = dirname(__FILE__);
# write httphost to file
$httphostfile = "$basedir/log/httphost.txt";
`echo $http_host > $httphostfile`;
$binpath = "$basedir/bin";
$projectfoldername = dirname($_SERVER['PHP_SELF']);

date_default_timezone_set('Europe/Stockholm'); #set default timezone to avoid warning

$ref_pconsc2="Skwark M.J., Raimondi D., Michel M.. and Elofsson A.  \"Improved contact predictions using the recognition of protein like contact patterns\".";
$ref_pconsc="Skwark, M. J., Abdel-Rehim, A., & Elofsson, A. (2013). \"PconsC: combination of direct information methods and alignments improves contact prediction\". Bioinformatics, 29(14), 1815-1816.0";

$ref=array(
    'pconsc' => $ref_pconsc,
    'pconsc2' => $ref_pconsc2,
);

$citation=cite($ref['pconsc'] . "<br><br>" . $ref['pconsc2']);
$sequence="";
$target_name="";
if(isset($_POST{'user_domain_submission'}))
{

  $sequence=$_POST{'sequence'};
  $target_name=$_POST{'name'};
}

# $submission_form="
#     <table>
#         <tr>
#             <td class=\"contentheading\" width=\"100%\">Protein Residue-Residue Contact Prediction Server Submission Page</td>
#         </tr>
#         <tr></tr>
#     </table>
# 
#     <table class=\"contentpaneopen\">
#         <tr>
#             <td valign=\"top\" colspan=\"2\">
#                 Paste in your amino acid sequence in one letter code (at least 30 amino acids)
#                 <form method=\"post\" name=\"seq_form\">
#                     <textarea name=\"sequence\" rows=\"10\" cols=\"60\">$sequence</textarea>
#                     <table> 
#                         <p>Target name (max 20 chars) <input name=\"name\" value=\"$target_name\" type=\"text\" /> (optional)</p>
#                         <p>E-mail <input name=\"email\" type=\"text\" /> (optional)</p>
# 
#                         <script language=\"javascript\">
#                         <!--
#                         document.getElementById(\'options\').style.display = \'none\';
#                         //-->
#                         </script>
# 
#                         <p> <input type=\"submit\" name=do value=\"Submit\" /> <INPUT type=\"reset\" value=\"Clear\" />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\"Generate example input\" onclick=\"example_fill();\"></p>
#                     </table>
#                 </form>
#             </td>
#         </tr>
#     </table>
# $citation
# ";

$submission_form="

    <table style=\"margin-top: 30px; margin-bottom:200px\">
        <tr>
            <td valign=\"top\" colspan=\"2\">
                <font size=4>
                Please submit your query to our new version of contact prediction server <a href=http://pconsc3.bioinfo.se><b>PconsC3 (http://pconsc3.bioinfo.se)</b></a>
                for better performance and speed.
                </font>
            </td>
        </tr>
    </table>
$citation
";

if(isset($_POST{'do'}) && $_POST{'do'}=="Submit")/*{{{*/
{
    #Checking input for errors....
    $sequence_errors=0;
    $email_errors=0;

    $fasta_info="NONAME";

    if(isset($_POST{'sequence'}))
    {
#         $in_seq = strtoupper(htmlspecialchars($_POST{'sequence'}));
        $in_seq = $_POST{'sequence'};
        $lines = preg_split('/\n/',$in_seq); 
        $sequence="";
        foreach ($lines as $line)
        {
            #  print $line."[new] <br>\n";
            if(preg_match('/>(.+)/',$line,$matches))
            {
                #print "FASTA INFO $fasta_info <br>\n";
                #print_r($matches);
                $fasta_info=$matches[1];
                # print "FASTA INFO $fasta_info <br>\n";
            }
            else
            {
                $sequence.="$line";
            }
        }
        #print "<hr>";
        #print $fasta_info."[new]";
        #print "<hr>";
        #print $sequence."[new]";
        $sequence=strtoupper($sequence);
        $sequence=preg_replace('/\s+/','',$sequence);
        $check_sequence=preg_replace('/[ACDEFGHIKLMNPQRSTVWY]/','',$sequence);


        if(strlen($check_sequence))
        {
            $len=strlen($check_sequence);
            $s="";
            if($len>1)
                $s="s";
            $sequence_errors="The sequence contains $len non-standard amino acid$s ($check_sequence)";
        }

        $check_sequence=preg_replace('/[ACGTUN]/','',$sequence);

        if ((strlen($check_sequence) == 0) and (strlen($sequence) > 200))
        {
            $sequence_errors="Your sequence seems to be a nucleotide strain.";
        }

        if (strlen($sequence) > 800)
        {
            $sequence_errors="Sequence too long. Try splitting your protein into putative domains.";
        }

        if(strlen($sequence)==0)
            $sequence_errors="Missing sequence";


        $email="N/A";
        if(isset($_POST{'email'}))
        {
            if(strlen($_POST{'email'})>4)
            {
                $email=htmlspecialchars($_POST{'email'});
                $email_errors=check_email_address($email);
            }

        }
    }
    $name=$fasta_info;
    $plain_text_name = $fasta_info; # preserve plain text name, without %20 html code
    if(isset($_POST{'name'}))
    {
        if(strlen($_POST{'name'})>0)
        {
            $plain_text_name = $_POST{'name'};
            $name=preg_replace('/\n/','',$name);
            $name=preg_replace('/\//',' ',$name);
            $name=preg_replace('/\s+/','%20',$name);
            $name=htmlspecialchars($_POST{'name'});
        }
    }
    $name = trim($name);
    $plain_text_name = trim($plain_text_name);
    $name=preg_replace('/\n/','',$name);
    $name=preg_replace('/\//',' ',$name);
    $name=preg_replace('/\s+/','%20',$name);

    $isCASPtarget = 0;
    if (preg_match('/predictioncenter\.org/', $email) || preg_match('/CASP/', $name))
    {
        $isCASPtarget = 1;
    }


    # $sequence_errors=1;
    if($sequence_errors=="0" && $email_errors=="0")
    {
        $url_to_post = "http://$http_host/$projectfoldername/cgi-bin/submit_query_fe.cgi";
        $str = `curl $url_to_post -d email=$email -d seq=$sequence -d host=$host -d name=$name -d httphost=$http_host`;
        #print "str=$str<br>";

        #preg_match('/\d+$/',$str,$matches);
        $fields = preg_split('/\s+/', $str);
        $numfield = count($fields);
        $folder_nr = $fields[$numfield-1];

        $user_heading="Submission successful!";
        $nice_seq=format_sequence($sequence);

        $user_text="Your sequence ";

        if(strlen($name)>0)
        {
            $user_text .= "named \"$plain_text_name\"";
        }

        if(strstr($str, 'new job ID'))
        {
            $user_text.=": <br /> <font color=#555555><pre>$nice_seq</pre></font>
                has been submitted to the queue (<b>$str</b>). <br><br>
                The progress of the job can be monitored <a  rel=\"nofollow\" href=index.php?queue>here</a>.<br />";
        }
        else
        {
            $user_heading="<font color=red>Sequence already submitted!</font>";
            $user_text.=": <br> <font color=#555555><pre>$nice_seq</pre></font>
                has already been submitted (<b>$str</b>). <br><br>Please click
                <a rel=\"nofollow\" href=index.php?id=$folder_nr>here</a> to see details.<br>";
        }
    }
    else
    {
        $user_heading="Error";
        $user_text="";
        if($sequence_errors!="0")
        {
            $user_text="$user_text"."Sequence Error: # $sequence_errors<br />";
        }
        if($email_errors!="0")
        {
            $user_text="$user_text"."Email Error: # $email_errors<br />";
        }

        $user_text="$user_text"."Please go <a href=javascript:history.go(-1)>back</a> and try again.";
    }

    $text="<tr><td class=\"contentheading\" width=\"100%\">$user_heading</td>
        </tr><tr> </tr></table><table class=\"contentpaneopen\"><tr><td valign=\"top\" colspan=\"2\">
        $user_text                   
        </td></tr></table><span class=\"article_seperator\">&nbsp;</span>";
}/*}}}*/
elseif(isset($_GET{'queue'}))/*{{{*/
{
    $isRefreshPage = 1;
    $refresh_interval = "\"120\"";
    $heading="QUEUE";
    $queue_file = "$basedir/result/queue.html";
    #`cgi-bin/update_queue_file.pl`;
    $queue_data=file($queue_file);
    $filter="<form method=\"get\" action=index.php>\n<input type=\"hidden\" name=\"queue\" value=1> filter:<input name=\"filter\" type=\"text\" /> <input type=\"submit\" value=submit></form>";
    $search_pattern="";
    $submitted_pattern="";
    if(isset($_GET{'filter'}))
    {
        $submitted_pattern=$_GET{'filter'};
        # $submitted_pattern="tmp/\",\$init);print \"bug\";preg_grep(\"//\",";
        #print $submitted_pattern;
        if(strlen($submitted_pattern)>0)
        {
            $search_pattern="$submitted_pattern|<table|table>";
            $submitted_pattern="value=\"$submitted_pattern\"";
        }
    }

    $filter="<form method=\"get\">\n<input type=\"hidden\" name=\"queue\" value=1> filter:<input name=\"filter\" $submitted_pattern type=\"text\" /> <input type=\"submit\" value=submit></form>";
    #print join('<br>',$queue_data);

    $queue_data=preg_grep("/$search_pattern/",$queue_data);
    $queue_data=join(' ',$queue_data);
    #print $queue_data;
    $tmp=htmlspecialchars($search_pattern);
    # $queue_text="$filter<br>\nPATTERN:\"$tmp\"<br>\n$queue_data\n";
    $queue_text="$filter <br> $queue_data \n";


    $text="
        <tr><td class=\"contentheading\" width=\"100%\">All jobs</td></tr>
        <tr> </tr>
        </table>
        <table class=\"contentpaneopen\">
        <tr><td valign=\"top\" colspan=\"2\">
        $queue_text
        </td></tr></table>
        ";
}/*}}}*/
elseif(isset($_GET{'about'}))/*{{{*/
{
    $about=$_GET{'about'};

    if($about=='db')/*{{{*/
    {
        # Note: read the database list from the file at docroot
        $dblistfile = "dblist.txt";
        $content = file_get_contents($dblistfile);
        $lines = preg_split('/\n/',$content);
        $dbtable = array();
        foreach ($lines as $line){
            $strs = preg_split('/\s+/', $line);
            if (count($strs) == 2){
                $dbtable[$strs[0]] = $strs[1];
            }
        }
        $db_hhblits = $dbtable['DB_HHBLITS'];
        $db_blast   = $dbtable['DB_BLAST'];
        $db_hmmer =  $dbtable['DB_HMMER'];

        $basename_db_hhblits = basename($db_hhblits);
        $basename_db_blast = basename($db_blast);
        $basename_db_hmmer = basename($db_hmmer);

        $heading="Database status";
        $db_hhblits_file_date=date("F d Y H:i:s", filemtime($db_hhblits . "_a3m_db"));
        $db_blast_file_date=date("F d Y H:i:s", filemtime($db_blast . ".00.phr"));
        $db_hmmer_file_date=date("F d Y H:i:s", filemtime($db_hmmer));
        $bulk_text="<table cellspacing=\"10px\">\n";
        $bulk_text.="<tr><td align=left><b>HHBLITS</b>:</td><td> $basename_db_hhblits, $db_hhblits_file_date</td></tr>\n";
        $bulk_text.="<tr><td align=left><b>BLAST</b>: </td><td> $basename_db_blast, $db_blast_file_date</td></tr>\n";
        $bulk_text.="<tr><td align=left><b>HMMER</b>: </td><td> $basename_db_hmmer, $db_hmmer_file_date</td></tr>\n";
        $bulk_text.="</table>\n";
    }
    /*}}}*/
    if($about=='notice')/*{{{*/
    {
        # Note: read the database list from the file at docroot
        $heading="Notice board";
        $bulk_text = "";
        $bulk_text .="<table cellspacing=\"10px\">\n";
        $notice_file = "doc/notice.txt";
        $notice_text  = file_get_contents($notice_file);
        $bulk_text .= "
            $notice_text
            ";
        $bulk_text .= "</table>\n";
    }
    /*}}}*/
    if($about=='computenode')/*{{{*/
    {
        # Note: read the database list from the file at docroot
        $heading="Resource available for PconsC2";
        $bulk_text = "";
        $tmpstr = trim(shell_exec("cat computenode.txt"));
        $lines = preg_split('/\n/',$tmpstr); 
        $computenodelist = array();
        foreach ($lines as $line){
            $strs = preg_split('/\s+/', $line);
            if (count($strs) == 1){
                array_push($computenodelist,$strs[0]);
            }
        }
        foreach ($computenodelist as $computenode)
        {
            $projectname = "";
            if(preg_match('/debug/', $basedir)){
                $projectname = "debug.pconsc";
            }else{
                $projectname = "pconsc";
            }
            $url_to_post = "http://$computenode/$projectname/cgi-bin/get_avail_resource.cgi";
            $return_msg = `curl $url_to_post | html2text`;
            $lines2 = preg_split('/\n/',$return_msg); 
            $res_table = array();
            foreach ($lines2 as $line){
                $strs = preg_split('/\s+/', $line);
                if (count($strs) == 2 && preg_match('/num_/',$strs[0])){
                    $res_table[$strs[0]] = $strs[1];
                }
            }
            if (count($res_table)>0){
                $bulk_text .= "
                    <p>
                    On the computenode <b>$computenode</b><br><br>
                    <table border=0 cellspacing=1 cellpadding=0 width=200>
                    ";
                $key = "Total number of nodes:";
                $value = $res_table['num_total_node:'];
                $bulk_text .= "<tr>
                    <td>$key</td>
                    <td>$value</td>
                    </tr>";

                $key = "Number of vacant nodes:";
                $value = $res_table['num_avail_node:'];
                $bulk_text .= "<tr>
                    <td>$key</td>
                    <td>$value</td>
                    </tr>";

                $key = "Number of running nodes:";
                $value = $res_table['num_running_node:'];
                $bulk_text .= "<tr>
                    <td>$key</td>
                    <td>$value</td>
                    </tr>";

                $key = "Number of bad nodes:";
                $value = $res_table['num_bad_node:'];
                $bulk_text .= "<tr>
                    <td>$key</td>
                    <td>$value</td>
                    </tr>";

                $bulk_text .= "</table></p>";
            }
        }
    }
    /*}}}*/
    elseif($about=='pconsc')/*{{{*/
    {
        $heading="PconsC";
        #$citation=cite($ref['pconsc']);
        $citation=cite($ref['pconsc'] . "<br><br>" . $ref['pconsc2']);
        $bulk_text.="
            <p>
            Random forest prediction of contacts in protein tertiary structure 
            from primary structure.
            </p>

            <p>
            PconsC takes protein sequence as input data. Jackhmmer and HHblits 
            are then used to generate alignments at various levels of 
            confidence of homology.  For each alignment, contact predictions 
            are made using PSICOV and plmDCA. The combined output is then used 
            as basis for a random forest evaluation, which produces the final 
            result.
            </p>

            <p>More information available on: <a href=\"http://c.pcons.net\">http://c.pcons.net</a>.</p>

            <p>PconsC is also available from github: <a href=\"https://github.com/ElofssonLab/pconsc2 \">https://github.com/ElofssonLab/pconsc2</a></p>

            <br>
            <h3>Contact</h3>
            <table class=\"text\">
            <tr><td><b>Phone:</b></td><td> +46852481531</td></tr>
            <tr><td><b>Email:</b></td><td> <a href=\"mailto:arne@bioinfo.se?Subject=PconsC%20Web%20Server\">click here to contact Arne</a></td></tr>
            <tr><td><b>Address:</b></td><td> Arne Elofsson, Science for Life Laboratory, Box 1031, 17121 Solna, Sweden</td></tr>
            </table>
            <p class=\"text\">For the website: please contact <a href=\"mailto:nanjiang.shu@scilifelab.se?Subject=PconsC%20Web%20Server\">nanjiang.shu at scilifelab.se</a></p>
            $citation";
    }/*}}}*/
    elseif($about=='download')/*{{{*/
    {
        $heading="Download";
#         $citation=cite($ref['pconsc']);
        $bulk_text.="<table cellpadding=\"10\">";

        $filename = "download/pconsc2-vm.zip";
        $file_description = "pconsc2-vm.zip";
        $size_info = human_filesize(filesize($filename));
        $bulk_text .= "<tr><td><a href=\"$filename\">$file_description</a></td><td>($size_info)</td></tr>";
        $bulk_text.="<tr></tr>";
        $bulk_text.="<tr><td>Standalone PconsC2</td><td><a href=\"https://github.com/ElofssonLab/pconsc2\">https://github.com/ElofssonLab/pconsc2</a> (We strongly recommend the users to download this standalone version of PconsC if you have many sequences to process.)</td></tr>";

        $bulk_text.="</table>";
    }/*}}}*/


    if(!isset($heading))
    {
        $heading=$about;
        $bulk_text="BULK TEXT";
    }

    $text="<tr>
        <td class=\"contentheading\" width=\"100%\">$heading</td>
        </tr>
        <tr> </tr>
        </table>

        <table class=\"contentpaneopen\">
        <tr>
        <td valign=\"top\" colspan=\"2\">
        $bulk_text
        </td>
        </tr></table>
        ";
}/*}}}*/
elseif(isset($_GET{'id'}))/*{{{*/
{
    $id=$_GET{'id'};
    $jobdir="$basedir/result/$id/";
    $info = "";
    if (! file_exists($jobdir)){
        $info .= "<p><font color=\"red\" size=4>This job does not exist!</font></p>";
    }else{

        $namefile="$jobdir/name";
        $name=trim(shell_exec("cat $jobdir/name|sed s/NONAME//g"));

        $sequence = file_get_contents("$jobdir/sequence");
        $seqlength = strlen($sequence);
        $info .= "<p class=\"text\">";
        $info .= "Your submitted sequence: <a href=\"http://$http_host$projectfoldername/result/$id/sequence.fasta\">sequence.fasta ($seqlength aa)</a><br>";
        $info .= "</p>";

        $info .= "<p class=\"text\">";


        $jobstatus = get_job_status($jobdir);
        $colorstatus = get_color_jobstatus($jobstatus);
        $info .= "The status of your job is: <font color=$colorstatus>$jobstatus</font><br>";

        if ($jobstatus == "Queued"){
            $time_start = trim(shell_exec("cat $jobdir/date"));
            $time_now = date('Y-m-d H:i:s');
        }else{
            $time_start = trim(shell_exec("cat $jobdir/pconsc.start"));
            if (file_exists("$jobdir/pconsc.stop")){
                $time_now = trim(shell_exec("cat $jobdir/pconsc.stop"));
            } else {
                $time_now = date('Y-m-d H:i:s');
            }
        }
        $datetime1 = StrToTime($time_start);
        $datetime2 = StrToTime($time_now);
        $time_duration = ($datetime2-$datetime1);
        $time_suffix = "";
        if ($time_duration < 60){
            $time_suffix = "seconds";
        }elseif($time_duration < 60*60 ){
            $time_duration = $time_duration/(60);
            $time_suffix = "minutes";
        }elseif ($time_duration < 60*60*24){
            $time_duration = $time_duration/(60*60);
            $time_suffix = "hours";
        }else{
            $time_duration = $time_duration/(60*60*24);
            $time_suffix = "days";
        }
        $time_duration = number_format($time_duration,1);

        if($jobstatus != "Queued"){
            $info .= "Time running: $time_duration $time_suffix<br>";
        }else{
            $info .= "Time in queue: $time_duration $time_suffix<br>";
        }

        if ($jobstatus == "Running" || $jobstatus == "Rerun"){
            $runnode = trim(shell_exec("cat $jobdir/server_submitted"));
            $info .= "Running node: $runnode<br>";
            $refresh_interval="\"60\"";
        }

        if($jobstatus == "Finished") {
            $info .= get_html_result($jobdir, $id);
        } else{
            if($jobstatus != "Failed"){
                $isRefreshPage = 1;
            }
            if($jobstatus != "Queued"){
                $joblogfile = "$jobdir/run_log.txt";
                $logdata = file_get_contents($joblogfile);
                $logdata = "\"$logdata\"";
                $info .= "
                    <p class=\"text\"><b>Log of your job:</b></p>
                    <table border=\"1\">
                        <tr><td>
                            <object data=\"result/$id/run_log.txt\" type=\"text/plain\" 
                            width=\"600\" style=\"height: 300px\"> </object>
                        </td></tr>
                    </table>
                    ";
            }
        }
    }

    $text="
            <tr>
                <td class=\"contentheading\" width=\"100%\">$id : $name</td>
            </tr>
            <tr class=\"text\">
                <td class=\"text\" valign=\"top\" colspan=\"2\">
                    $info
                </td>
            </tr>

        <!--<span class=\"article_seperator\">&nbsp;</span>-->
    ";
}/*}}}*/
else/*{{{*/
{
  $text=$submission_form;
}/*}}}*/

#print $text;
# print "refresh_interval=$refresh_interval\n";
if ($isRefreshPage){
    $tplObj_refresh->varRef( "pconsc", array(
        "DATE"    =>    date("l, F j Y"),
        "TEXT"    =>    "$text",
        "REFRESHINTERVAL" => "$refresh_interval",
    ));
    $tplObj_refresh->parseDynamic("pconsc");
}
else{
    $tplObj->varRef( "pconsc", array(
        "DATE"    => date("l, F j Y"),
        "TEXT"    => "$text",
        "REFRESHINTERVAL" => "$refresh_interval",
    ));
    $tplObj->parseDynamic("pconsc");
}


function get_job_status($jobdir)/*{{{*/
{
    $status = "";
    if (! file_exists("$jobdir/pconsc.start")){
        $status="Queued";
    }else{
        if (file_exists("$jobdir/pconsc.stop")){
            if ( file_exists("$jobdir/pconsc.success")){
                $status="Finished";
            }else{
                $status="Failed";
            }
        }else{
            if ( file_exists("$jobdir/pconsc.rerun")){
                $status="Rerun";
            }else{
                $status="Running";
            }
        }
    }
    return $status;
}/*}}}*/
function format_sequence($sequence) /*{{{*/
{
    global $host, $http_host, $basedir, $binpath, $projectfoldername; 
    $aa_vec=preg_split('//',$sequence);
    $sequence_nice="";
    $count=0;
    foreach ($aa_vec as $aa)
    {
        # print "$count $aa<br />";
        if(strlen($aa)==1)
        {
            if($count % 10 == 0 && $count>0)
            {
                $sequence_nice="$sequence_nice ";
            }
            if($count % 60 == 0 && $count > 0)
            {
                $sequence_nice="$sequence_nice\n";
            }

            $sequence_nice="$sequence_nice$aa";
            $count++;
        }
    }

    return($sequence_nice);

}/*}}}*/

function check_email_address($email) {/*{{{*/
    global $host, $http_host, $basedir, $binpath, $projectfoldername; 
    // First, we check that there's one @ symbol, and that the lengths are right
    if (!ereg("^[^@]{1,64}@[^@]{1,255}$", $email)) {
        #print "// Email invalid because wrong number of characters in one section, or wrong number of @ symbols.";
        return "Email (\"$email\") invalid because wrong number of characters in one section, or wrong number of @ symbols.";
    }
    // Split it into sections to make life easier
    $email_array = explode("@", $email);
    $local_array = explode(".", $email_array[0]);
    for ($i = 0; $i < sizeof($local_array); $i++) {
        if (!ereg("^(([A-Za-z0-9!#$%&'*+/=?^_`{|}~-][A-Za-z0-9!#$%&'*+/=?^_`{|}~\.-]{0,63})|(\"[^(\\|\")]{0,62}\"))$", $local_array[$i])) {
            #  return false;
            return "Email (\"$email\") invalid";
        }
    }  
    if (!ereg("^\[?[0-9\.]+\]?$", $email_array[1])) { // Check if domain is IP. If not, it should be valid domain name
        $domain_array = explode(".", $email_array[1]);
        if (sizeof($domain_array) < 2) {
            return "Email (\"$email\") invalid beacuse not enought parts to be a domain";
            // Not enough parts to domain
        }
        for ($i = 0; $i < sizeof($domain_array); $i++) {
            if (!ereg("^(([A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9])|([A-Za-z0-9]+))$", $domain_array[$i])) {
                return "Email (\"$email\") invalid";
            }
        }
    }
    return 0;
}/*}}}*/

function http_get( $url ) {/*{{{*/
    global $host, $http_host, $basedir, $binpath, $projectfoldername; 
    $request = fopen( $url, "rb" );
    #  return fread($request, 8192);
    $result = "";
    while( !feof( $request ) ) {
        $result .= fread( $request, 8192 );
    }

    # fclose( $request );

    return $result;
}/*}}}*/
function get_color_jobstatus($status)/*{{{*/
{
    $color_failed="red";
    $color_queued="black";
    $color_running="blue";
    $color_rerun="orange";
    $color_finished ="green";

    $colorstatus = "black";
    if  ($status == "Queued"){
        $colorstatus = $color_queued;
    }elseif($status == "Running"){
        $colorstatus = $color_running;
    }elseif($status == "Finished"){
        $colorstatus = $color_finished;
    }elseif($status == "Rerun"){
        $colorstatus = $color_rerun;
    }elseif($status == "Failed"){
        $colorstatus = $color_failed;
    }
    return $colorstatus;
}/*}}}*/

function get_html_result($jobdir, $id)/*{{{*/
{
    $content = "";
    $fig_pconsc1 = "result/$id/pconsc/sequence.fasta.pconsc.out.cm.png";
    $fig_pconsc2 = "result/$id/pconsc/sequence.fasta.pconsc2.out.cm.png";
    $resultfile_pconsc1 = "result/$id/pconsc/sequence.fasta.pconsc.out";
    $resultfile_pconsc2 = "result/$id/pconsc/sequence.fasta.pconsc2.out";
    $logfile = "result/$id/pconsc/log.txt";
    $tarball = "result/$id/pconsc.tar.gz";
    $fastafile = "result/$id/pconsc/sequence.fasta";
    $name=trim(shell_exec("cat result/$id/name"));
    $email=trim(shell_exec("cat result/$id/email"));
    $casp_outfile= "result/$id/CASP11_RR_pconsc2.txt";

    $isCASPtarget = 0;
    if (preg_match('/predictioncenter\.org/', $email) && preg_match('/^T/', $name)) {
        $isCASPtarget = 1;
    }
    if ($isCASPtarget && ! file_exists($casp_outfile)){
        $app_output_info = `cgi-bin/reformat_casp.py $fastafile $resultfile_pconsc2 $name $casp_outfile`;
        #$content .= "cgi-bin/reformat_casp.py $fastafile $resultfile_pconsc2 $name $casp_outfile";
    }

    $content .= "
        <h3>Download results:</h3>
        <table>
        ";
    if (file_exists("$resultfile_pconsc2")){
        $content .= "
            <tr > <td class=\"text\" ><a href=\"$resultfile_pconsc2\">PconsC2 prediction</a></td> </tr>
            ";
    }
    if (file_exists("$resultfile_pconsc1")){
        $content .= "<tr > <td class=\"text\" ><a href=\"$resultfile_pconsc1\">PconsC1 prediction</a></td> </tr>
            ";
    }
    $content .= "
            <tr > <td class=\"text\" ><a href=\"$tarball\">Tarball with all intermediary predictions</a></td></tr>
            <tr > <td class=\"text\" ><a href=\"$logfile\">log file</a></td></tr>
        ";
    if ($isCASPtarget && file_exists($casp_outfile))
    #if ($isCASPtarget )
    {
        $content .= "<tr > <td class=\"text\" ><a href=\"$casp_outfile\">PconsC2 result in CASP format</a></td></tr>";
    }
    $content .="</table>";
    $content .="
        <table>
        ";
    if (file_exists("$fig_pconsc2")){
        $content .= "
            <tr>
                <td><font size=\"2\">PconsC2</font></td><td> <img src=\"$fig_pconsc2\" width=\"500\" height=\"500\"></td>
            </tr>
            ";
    }
    if (file_exists("$fig_pconsc1")){

        $content .= "
            <tr>
                <td><font size=\"2\">PconsC1</font></td><td><img src=\"$fig_pconsc1\" width=\"500\" height=\"500\"> </td>
            </tr>
            ";
    }
    $content .="
        </table>
    ";
    return $content;
}/*}}}*/
function cite($ref) {/*{{{*/
    return "<span class=\"article_seperator\">&nbsp;</span><table class=\"contentpaneopen\"><tr><td class=\"contentheading\" width=\"100%\" valign=\"top\">References</td></tr></table><table class=\"contentpaneopen\"><tr><td valign=\"top\" colspan=\"2\">$ref</td></tr></table>";
}/*}}}*/

function human_filesize($bytes, $decimals = 1) {/*{{{*/
    $size = array('B','kB','MB','GB','TB','PB','EB','ZB','YB');
    $factor = floor((strlen($bytes) - 1) / 3);
    return sprintf("%.{$decimals}f", $bytes / pow(1024, $factor)) . @$size[$factor];
}/*}}}*/
?>

