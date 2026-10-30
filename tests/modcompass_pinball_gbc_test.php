<?php
// ROM-free edition contract regression, contributions by Roxas2712.
declare(strict_types=1);
require __DIR__.'/../operations/modcompass/pinball-gbc/RetroPinballGbcRules.php';
use App\Services\RetroPinballGbcRules as Rules;
$checks = 0;
function check(bool $ok, string $why): void { global $checks; if (! $ok) { throw new RuntimeException($why); } $checks++; }
function reject(array $rules, ?string $fingerprint = null): void {
    try { Rules::validate($rules, $fingerprint ?? str_repeat('0', 64)); }
    catch (InvalidArgumentException $e) { check(true, 'rejected'); return; }
    throw new RuntimeException('Invalid rules accepted');
}
$valid = ['protocol'=>1,'field'=>0,'frames'=>18000,'seed'=>0,'rom'=>Rules::ROM,
    'backend'=>'gbrecompiled-'.Rules::RUNTIME.'-'.str_repeat('a',16),'content'=>'USA-'.Rules::ROM,'locale'=>'en'];
check(Rules::supports('pinballgbc') && ! Rules::supports('pinballrs') && ! Rules::supports('gold'), 'edition boundary');
$hash = Rules::fingerprint($valid);
check(Rules::validate($valid, $hash) === $valid, 'red identity');
$blue=$valid; $blue['field']=1;
check(Rules::validate($blue, Rules::fingerprint($blue)) === $blue, 'blue identity');
foreach (['protocol'=>2,'field'=>2,'frames'=>600,'seed'=>1,'rom'=>'9fec81ce2c5df589e0371a0bf2f92a5fe8db730b','backend'=>'gba-build','content'=>'EU-'.Rules::ROM,'locale'=>'de'] as $key=>$value) {
    $bad=$valid; $bad[$key]=$value; reject($bad);
}
foreach (['field'=>'0','frames'=>18000.0,'seed'=>false,'backend'=>[], 'rom'=>null] as $key=>$value) { $bad=$valid; $bad[$key]=$value; reject($bad); }
$bad=$valid; $bad['party']=[]; reject($bad);
$bad=$valid; unset($bad['locale']); reject($bad);
reject($valid, str_repeat('0',64)); reject($valid, strtoupper($hash)); reject($valid, $hash."\n");
check($hash === hash('sha256', "pinball-duel-v1\n".$valid['rom']."\n".$valid['backend']."\n".$valid['content']), 'same fingerprint as native client');
echo "$checks GBC server edition-contract checks passed (no server or accounts)\n";
