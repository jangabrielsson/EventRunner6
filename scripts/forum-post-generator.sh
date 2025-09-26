#!/bin/bash

# Forum post generator for Fibaro Forum
generate_forum_post() {
    local version=$1
    local release_notes=$2
    local github_url="https://github.com/jangabrielsson/EventRunner6"
    
    # Convert markdown-style formatting for HTML display
    local formatted_notes=$(echo "$release_notes" | \
        sed 's/^### \(.*\)/<h4>\1<\/h4>\n/g' | \
        sed 's/^## \(.*\)/<h3>\1<\/h3>\n/g' | \
        sed 's/^- \(.*\)/<li>\1<\/li>/g' | \
        sed 's/^\* \(.*\)/<li>\1<\/li>/g' | \
        sed 's/^\*\(.*\)\*$/<p><em>\1<\/em><\/p>/g' | \
        awk 'BEGIN{in_list=0} 
             /^<li>/ {
                 if(!in_list){print "<ul>"; in_list=1} 
                 print; next
             } 
             {
                 if(in_list){print "</ul>"; in_list=0} 
                 if($0 != "") print
             } 
             END{if(in_list)print "</ul>"}' | \
        sed 's/\*\*\([^*]*\)\*\*/\<strong\>\1\<\/strong\>/g')
    
    # Create HTML forum post in doc/notes directory (using temp file to avoid race conditions)
    local temp_file=$(mktemp)
    cat > "$temp_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>EventRunner 6 v$version - Forum Post</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: white;
            color: #333;
            max-width: 800px;
            margin: 20px auto;
            padding: 20px;
            line-height: 1.6;
        }
        .post-content {
            background: #fafafa;
            border: 1px solid #e1e1e1;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .copy-button {
            background: #0366d6;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            margin-bottom: 10px;
        }
        .copy-button:hover {
            background: #0256cc;
        }
        .forum-link {
            background: #28a745;
            color: white;
            text-decoration: none;
            padding: 10px 20px;
            border-radius: 4px;
            display: inline-block;
            margin-left: 10px;
        }
        .forum-link:hover {
            background: #218838;
        }
        h2 { color: #0366d6; }
        h3 { color: #586069; }
        code { background: #f6f8fa; padding: 2px 4px; border-radius: 3px; }
        .emoji { font-size: 1.2em; }
    </style>
</head>
<body>
    <h1>EventRunner 6 v$version - Forum Post Helper</h1>
    
    <div>
        <button class="copy-button" onclick="copyToClipboard()">📋 Copy Forum Post</button>
        <a href="https://forum.fibaro.com/topic/79165-eventrunner-6/" class="forum-link" target="_blank">🌐 Open Fibaro Forum Thread</a>
    </div>
    
    <div class="post-content" id="forumPost">
<h2>🚀 EventRunner 6 - Release v$version</h2>

$formatted_notes

<h3>📥 <strong>Download</strong></h3>
<ul>
<li><strong>GitHub Releases</strong>: <a href="$github_url/releases/tag/v$version">$github_url/releases/tag/v$version</a></li>
<li><strong>Direct .fqa files</strong>: <a href="$github_url/releases/download/v$version/EventRunner6.fqa">EventRunner6.fqa</a>, <a href="$github_url/releases/download/v$version/ERUpdater.fqa">ERUpdater.fqa</a></li>
</ul>

<h3>📚 <strong>Documentation</strong></h3>
<ul>
<li><strong>Full Documentation</strong>: <a href="$github_url/blob/main/README.md">$github_url/blob/main/README.md</a></li>
</ul>

<hr>
<p><em>This release was automatically generated from commit $(git rev-parse --short HEAD)</em></p>
    </div>

    <script>
        function copyToClipboard() {
            const postContent = document.getElementById('forumPost');
            const range = document.createRange();
            range.selectNode(postContent);
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
            
            try {
                document.execCommand('copy');
                const button = document.querySelector('.copy-button');
                const originalText = button.textContent;
                button.textContent = '✅ Copied!';
                button.style.background = '#28a745';
                setTimeout(() => {
                    button.textContent = originalText;
                    button.style.background = '#0366d6';
                }, 2000);
            } catch (err) {
                alert('Please manually select and copy the content below');
            }
            
            window.getSelection().removeAllRanges();
        }
    </script>
</body>
</html>
EOF

    # Move temp file to final location atomically and ensure it's fully written
    mv "$temp_file" "doc/notes/release-v$version.html"
    
    # Wait for file to be fully available and verify it has content
    local retries=0
    while [ $retries -lt 10 ]; do
        if [ -s "doc/notes/release-v$version.html" ]; then
            break
        fi
        sleep 0.1
        retries=$((retries + 1))
    done
    
    echo "✅ Forum post created: doc/notes/release-v$version.html"
    echo "📋 Copy and paste this content to: https://forum.fibaro.com/topic/79165-eventrunner-6/"
}

# Export function for use in release script
export -f generate_forum_post

# If script is run directly (not sourced), call the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <version> <release_notes>"
        echo "Example: $0 1.0.0 'Bug fixes and improvements'"
        exit 1
    fi
    
    generate_forum_post "$1" "$2"
fi
