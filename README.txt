# jira-issues-reporter
JIRAのアジャイルボードの情報を取得する対話型ツールです。

# 使い方
同じディレクトリに`token.txt`を以下の内容で作成してください。

```token.txt
email=(あなたのJIRAアカウントメールアドレス)
token=(あなたのJIRA APIトークン)
```

その後、以下を実行してください。

```
$ ruby inspect_tickets.rb
```
