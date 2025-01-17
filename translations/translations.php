<?php
// Default URL (English-US)
$baseUrl = 'https://raw.githubusercontent.com/icefields/Power-Ampache-2/refs/heads/main/app/src/main/res/values';
$defaultUrl = $baseUrl.'/strings.xml';

// Available URLs, must add new links manually. Look into automating this.
$urls = [
    'English-US' => $defaultUrl,
    'Czech' => $baseUrl.'-cs/strings.xml',
    'Japanese' => $baseUrl.'-jp/strings.xml',
    'Italian' => $baseUrl.'-it/strings.xml',
    'Spanish' => $baseUrl.'-es/strings.xml',
    'German' => $baseUrl.'-de/strings.xml',
    'French' => $baseUrl.'-fr/strings.xml',
    'Russian' => $baseUrl.'-ru/strings.xml'
];

// Get the selected language URL from the form or use default
$selectedUrl = isset($_POST['language']) && isset($urls[$_POST['language']]) ? $urls[$_POST['language']] : $defaultUrl;

// Load the XML file
$xml = simplexml_load_file($selectedUrl);

// Check if the XML file was successfully loaded
if ($xml === false) {
    echo "Failed to load XML file.";
    exit;
}

// Initialize arrays to store names and contents
$names = [];
$contents = [];

// Iterate through each <string> element in the XML
foreach ($xml->string as $string) {
    $names[] = (string)$string['name'];
    $contents[] = (string)$string;
}

// Handle form submission (save new content)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['content'])) {
    // Loop through each textarea and update the corresponding XML node
    foreach ($names as $index => $name) {
        $newContent = $_POST['content'][$index];
        $xml->string[$index] = $newContent;
    }

    // Set headers to trigger a download in the browser
    header('Content-Type: application/xml');
    header('Content-Disposition: attachment; filename="strings.xml"');
    
    // Output the updated XML content as a download
    echo $xml->asXML();

    // Stop further script execution after outputting the file
    exit;
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Power Ampache 2 translations</title>
</head>
<body>

<h1>Power Ampache 2 Translations</h1>

<form method="POST" action="">
    <label for="language">Select Language: </label>
    <select name="language" id="language" onchange="this.form.submit()">
        <?php
        foreach ($urls as $label => $url) {
            $selected = ($url == $selectedUrl) ? 'selected' : ''; 
            echo "<option value=\"$label\" $selected>$label</option>";
        }
        ?>
    </select>
</form>

<form method="POST">
    <?php
    echo '<br>';
    for ($i = 0; $i < count($names); $i++) {
        echo '<b>' . htmlspecialchars($names[$i]) . '</b>'.'<br>';
        echo '<textarea name="content[]" rows="1" cols="100">' . htmlspecialchars($contents[$i]) . '</textarea><br><br>';
    }
    ?>

    <!-- Submit button to save the changes -->
    <button type="submit">Save Changes</button>
</form>

</body>
</html>

