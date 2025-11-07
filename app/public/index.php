<?php
// Rota de saúde simples
if (isset($_SERVER['REQUEST_URI']) && $_SERVER['REQUEST_URI'] === '/healthz') {
  http_response_code(200);
  echo "ok";
  exit;
}

$required = ['DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASS'];
foreach ($required as $k) {
  if (empty($_ENV[$k])) {
    http_response_code(500);
    echo "Falta variável: $k";
    exit;
  }
}

$dsn = "mysql:host=".$_ENV['DB_HOST'].";port=".$_ENV['DB_PORT'].";dbname=".$_ENV['DB_NAME'].";charset=utf8mb4";
$options = [
  PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
];

try {
  $pdo = new PDO($dsn, $_ENV['DB_USER'], $_ENV['DB_PASS'], $options);
  $stmt = $pdo->query("SELECT NOW()");
  $now  = $stmt->fetchColumn();
  echo "<h1>PHP 8.2 + Apache</h1>";
  echo "<p>Ligação MySQL OK à base <b>".$_ENV['DB_NAME']."</b></p>";
  echo "<p>Hora no MySQL: ".$now."</p>";
} catch (Throwable $e) {
  http_response_code(500);
  echo "Erro ao ligar ao MySQL: ".$e->getMessage();
}
