<?php

require_once('vpopadm.inc.php');

unset($_SESSION['AdminID']);
unset($_SESSION['Privilidge']);

session_unset();
session_destroy();

?>
<br>
<br>
<br>
<br>
<br>
<br>
<br>
<div align="center">
已成功退出。请关闭此窗口
</div>