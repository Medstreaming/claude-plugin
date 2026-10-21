<#
.SYNOPSIS
    Reports SQL identifiers that collide with T-SQL reserved keywords.

.DESCRIPTION
    Catches the class of bug where a column aliased AS LineNo fails to parse because LINENO is
    reserved, producing "Incorrect syntax near the keyword 'LineNo'" plus a cascade of bogus
    follow-on errors.

    Extracts three kinds of identifier from each script:
      * bracketed names          [MyColumn]
      * select-list aliases      ... AS MyAlias,
      * column declarations      MyColumn int NULL

    Bracketed names are reported as INFO because brackets make them legal - but renaming is
    still preferred, since every future unbracketed reference will fail.

.PARAMETER Path
    One or more paths or globs. Defaults to every .sql file under sql/.

.EXAMPLE
    ./Check-SqlReservedWords.ps1 -Path 'sql\Task_38396_*.sql'

.EXAMPLE
    ./Check-SqlReservedWords.ps1
#>
[CmdletBinding()]
param(
    [string[]]$Path = 'sql\*.sql'
)

$ErrorActionPreference = 'Stop'

# T-SQL reserved keywords (SQL Server). Also mirrored in
# Medstreaming.SupportUtility/3rdParties/FastColoredTextBox/SyntaxHighlighter.cs
$reserved = @'
ADD ALL ALTER AND ANY AS ASC AUTHORIZATION BACKUP BEGIN BETWEEN BREAK BROWSE BULK BY
CASCADE CASE CHECK CHECKPOINT CLOSE CLUSTERED COALESCE COLLATE COLUMN COMMIT COMPUTE
CONSTRAINT CONTAINS CONTAINSTABLE CONTINUE CONVERT CREATE CROSS CURRENT CURRENT_DATE
CURRENT_TIME CURRENT_TIMESTAMP CURRENT_USER CURSOR DATABASE DBCC DEALLOCATE DECLARE
DEFAULT DELETE DENY DESC DISK DISTINCT DISTRIBUTED DOUBLE DROP DUMP ELSE END ERRLVL
ESCAPE EXCEPT EXEC EXECUTE EXISTS EXIT EXTERNAL FETCH FILE FILLFACTOR FOR FOREIGN
FREETEXT FREETEXTTABLE FROM FULL FUNCTION GOTO GRANT GROUP HAVING HOLDLOCK IDENTITY
IDENTITYCOL IDENTITY_INSERT IF IN INDEX INNER INSERT INTERSECT INTO IS JOIN KEY KILL
LEFT LIKE LINENO LOAD MERGE NATIONAL NOCHECK NONCLUSTERED NOT NULL NULLIF OF OFF
OFFSETS ON OPEN OPENDATASOURCE OPENQUERY OPENROWSET OPENXML OPTION OR ORDER OUTER OVER
PERCENT PIVOT PLAN PRECISION PRIMARY PRINT PROC PROCEDURE PUBLIC RAISERROR READ
READTEXT RECONFIGURE REFERENCES REPLICATION RESTORE RESTRICT RETURN REVERT REVOKE RIGHT
ROLLBACK ROWCOUNT ROWGUIDCOL RULE SAVE SCHEMA SECURITYAUDIT SELECT SEMANTICKEYPHRASETABLE
SEMANTICSIMILARITYDETAILSTABLE SEMANTICSIMILARITYTABLE SESSION_USER SET SETUSER SHUTDOWN
SOME STATISTICS SYSTEM_USER TABLE TABLESAMPLE TEXTSIZE THEN TO TOP TRAN TRANSACTION
TRIGGER TRUNCATE TRY_CONVERT TSEQUAL UNION UNIQUE UNPIVOT UPDATE UPDATETEXT USE USER
VALUES VARYING VIEW WAITFOR WHEN WHERE WHILE WITH WITHIN WRITETEXT
'@ -split '\s+' | Where-Object { $_ } | ForEach-Object { $_.ToUpperInvariant() }

# Identifiers that are legitimately reserved words in normal usage
$ignore = @('PRIMARY', 'SELECT', 'DEFAULT', 'KEY', 'INDEX', 'TABLE', 'VIEW', 'IDENTITY')

$files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue
if (-not $files) { Write-Warning "No files matched: $($Path -join ', ')"; exit 0 }

$problems = 0

foreach ($f in $files) {
    $text = Get-Content -Raw $f.FullName
    $found = @{}   # identifier -> kind

    foreach ($m in [regex]::Matches($text, '\[([A-Za-z_][A-Za-z0-9_]*)\]')) {
        $n = $m.Groups[1].Value; if (-not $found.ContainsKey($n)) { $found[$n] = 'bracketed' }
    }
    foreach ($m in [regex]::Matches($text, '(?i)\bAS\s+([A-Za-z_][A-Za-z0-9_]*)\s*[,\r\n]')) {
        $found[$m.Groups[1].Value] = 'alias'
    }
    # Unbracketed column declarations only - a bracketed [User] int NULL is legal
    foreach ($m in [regex]::Matches($text, '(?im)^\s+([A-Za-z_][A-Za-z0-9_]*)\s+\[?(int|bigint|smallint|tinyint|bit|varchar|nvarchar|char|nchar|datetime|datetime2|date|decimal|numeric|float|real|money|uniqueidentifier)\b')) {
        $n = $m.Groups[1].Value; if ($found[$n] -ne 'alias') { $found[$n] = 'column' }
    }

    $hits = @()
    foreach ($n in ($found.Keys | Sort-Object)) {
        $u = $n.ToUpperInvariant()
        if ($reserved -contains $u -and $ignore -notcontains $u) {
            $hits += [pscustomobject]@{ Name = $n; Kind = $found[$n] }
        }
    }

    if ($hits.Count) {
        Write-Host "`n$($f.Name)" -ForegroundColor Yellow
        foreach ($h in $hits) {
            if ($h.Kind -eq 'bracketed') {
                Write-Host ("  INFO  [{0}] is reserved - legal only while bracketed; rename is safer" -f $h.Name) -ForegroundColor DarkYellow
            }
            else {
                Write-Host ("  FAIL  {0} ({1}) is a RESERVED keyword and will not parse unquoted" -f $h.Name, $h.Kind) -ForegroundColor Red
                $problems++
            }
        }
    }
}

Write-Host ''
if ($problems -eq 0) {
    Write-Host "OK - no unquoted reserved-word identifiers in $($files.Count) file(s)." -ForegroundColor Green
    exit 0
}
Write-Host "$problems reserved-word identifier(s) must be renamed." -ForegroundColor Red
exit 1
