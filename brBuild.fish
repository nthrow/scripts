#!/usr/bin/env fish
# build breviary epubs from a private Divinum Officium backend
# requires docker, and the divinumofficium and doepub images

set -l networkName "liturgy-net"
set -l backendName "divinum-backend"
set -l doepubImage "mbab1/doepub"
set -l divinumImage "ghcr.io/divinumofficium/divinum-officium:master"
set -l rubrics "Rubrics 1960 - 1960"

argparse \
    k/keep \
    a/all \
    q/quarterly \
    m/monthly \
    -- $argv

if test $status -ne 0
    echo "Usage: $argv[1] [-k] [-a] [-q] [-m] <startYear> [<endYear>]"
    echo "Options:"
    echo "  -k, --keep       Keep containers running after completion"
    echo "  -a, --all        Generate annual + quarterly + monthly EPUBs"
    echo "  -q, --quarterly  Generate quarterly EPUBs (brYYQ#.epub)"
    echo "  -m, --monthly    Generate monthly EPUBs (brYYMM.epub)"
    exit 1
end

if set -q _flag_k
    set keepRunning 1
else
    set keepRunning 0
end

set -l modes
if set -q _flag_a
    set modes annual quarterly monthly
else
    if set -q _flag_q
        set modes $modes quarterly
    end
    if set -q _flag_m
        set modes $modes monthly
    end
    if test (count $modes) -eq 0
        set modes annual
    end
end

if test (count $argv) -lt 1
    echo "Usage: $argv[1] [-k] [-a] [-q] [-m] <startYear> [<endYear>]"
    echo "Options:"
    echo "  -k, --keep       Keep containers running after completion"
    echo "  -a, --all        Generate annual + quarterly + monthly EPUBs"
    echo "  -q, --quarterly  Generate quarterly EPUBs (brYYQ#.epub)"
    echo "  -m, --monthly    Generate monthly EPUBs (brYYMM.epub)"
    echo ""
    echo "Examples:"
    echo "  $argv[1] 2026                # annual only"
    echo "  $argv[1] -q 2026 2030        # quarterly for 2026-2030"
    echo "  $argv[1] -m 2026             # monthly for 2026"
    echo "  $argv[1] -a 2026 2030        # all formats for 2026-2030"
    echo "  $argv[1] -k 2026             # keep containers, annual"
    exit 1
end

set -l startYear $argv[1]

if test (count $argv) -eq 1
    set endYear $startYear
else
    set endYear $argv[2]
end

if not string match -q --regex '^[0-9]{4}$' "$startYear"
    echo "Error: Start year '$startYear' must be a 4-digit number."
    exit 1
end

if not string match -q --regex '^[0-9]{4}$' "$endYear"
    echo "Error: End year '$endYear' must be a 4-digit number."
    exit 1
end

if test $startYear -gt $endYear
    echo "Error: Start year ($startYear) cannot be greater than End year ($endYear)."
    exit 1
end

echo ">>> Initializing Breviary Build for $startYear to $endYear..."
if test $keepRunning -eq 1
    echo ">>> Mode: Keep containers after build"
else
    echo ">>> Mode: Stop containers after build"
end

echo ">>> Generation Modes: $modes"

echo ">>> Checking Docker network '$networkName'..."
if not docker network inspect $networkName >/dev/null 2>&1
    echo ">>> Creating network '$networkName'..."
    docker network create $networkName
    if test $status -ne 0
        echo "Error: Failed to create network."
        exit 1
    end
else
    echo ">>> Network '$networkName' exists."
end

echo ">>> Checking backend container '$backendName'..."

set -l containerList (docker ps -a --format '{{.Names}}')
set -l containerExists 0
set -l containerRunning 0

for name in $containerList
    if test "$name" = "$backendName"
        set containerExists 1
        if test (docker ps --filter "name=$backendName" --format '{{.Names}}' |wc -l) -gt 0
            set containerRunning 1
        end
        break
    end
end

if test $containerRunning -eq 1
    echo ">>> Container '$backendName' is already running. Reusing it."
else if test $containerExists -eq 1
    echo ">>> Container '$backendName' exists but is stopped. Starting it..."
    docker start $backendName
    if test $status -ne 0
        echo "Error: Failed to start existing container."
        exit 1
    end
else
    echo ">>> Container '$backendName' does not exist. Creating and starting..."
    docker run -d \
        --name $backendName \
        --network $networkName \
        -p 8080:8080 \
        $divinumImage
    if test $status -ne 0
        echo "Error: Failed to create container."
        exit 1
    end
end

echo ">>> Waiting for backend to initialize..."
set -l retries 30
while test $retries -gt 0
    if docker exec $backendName curl -s --max-time 2 http://localhost:8080 >/dev/null 2>&1
        echo ">>> Backend is ready."
        break
    end
    sleep 2
    set retries (math $retries - 1)
end

if test $retries -eq 0
    echo "Error: Backend container did not become ready in time."
    echo ">>> Logs:"
    docker logs $backendName
    exit 1
end

function isLeapYear
    set -l y $argv[1]
    if test (math "$y % 400") -eq 0
        return 0
    else if test (math "$y % 100") -eq 0
        return 1
    else if test (math "$y % 4") -eq 0
        return 0
    end
    return 1
end

function daysInMonth
    set -l month $argv[1]
    set -l year $argv[2]
    switch $month
        case 01 03 05 07 08 10 12
            echo 31
        case 04 06 09 11
            echo 30
        case 02
            if isLeapYear $year
                echo 29
            else
                echo 28
            end
    end
end

function getPeriods
    set -l year $argv[1]
    set -l mode $argv[2]

    switch $mode
        case annual
            echo "01-01-$year|12-31-$year|A"
        case quarterly
            echo "01-01-$year|03-31-$year|Q1"
            echo "04-01-$year|06-30-$year|Q2"
            echo "07-01-$year|09-30-$year|Q3"
            echo "10-01-$year|12-31-$year|Q4"
        case monthly
            for m in 01 02 03 04 05 06 07 08 09 10 11 12
                set -l lastDay (daysInMonth $m $year)
                echo "$m-01-$year|$m-$lastDay-$year|M$m"
            end
    end
end

set -l currentYear $startYear

while test $currentYear -le $endYear
    echo ">>> Processing Year: $currentYear"

    for mode in $modes
        echo ">>> Mode: $mode"
        set -l periods (getPeriods $currentYear $mode)

        for line in $periods
            set -l parts (string split '|' $line)

            if test (count $parts) -ne 3
                echo "   ERROR: Failed to parse period line: $line"
                continue
            end

            set -l startDate $parts[1]
            set -l endDate $parts[2]
            set -l periodLabel $parts[3]

            set -l shortYear (string sub -s 3 -l 2 $currentYear)
            set -l outputFile
            switch $mode
                case annual
                    set outputFile "br$currentYear.epub"
                case quarterly
                    set outputFile "br$shortYear$periodLabel.epub"
                case monthly
                    set -l monthNum (string sub -s 2 $periodLabel)
                    set outputFile "br$shortYear$monthNum.epub"
            end

            echo "   Generating: $outputFile ($startDate to $endDate)"

            if test -z "$outputFile"
                echo "   ERROR: Output filename is empty! Aborting."
                exit 1
            end

            docker run --rm \
                --user (id -u):(id -g) \
                -v (pwd):/tmp \
                --network $networkName \
                $doepubImage \
                -r $rubrics \
                -f $startDate \
                -t $endDate \
                -k canvas.jpg \
                -p http://divinum-backend:8080 \
                -o /tmp/$outputFile

            if test $status -ne 0
                echo "   ERROR: Failed to generate $outputFile"
            else
                echo "   Success: $outputFile created."
            end
        end
    end

    set currentYear (math $currentYear + 1)
end

echo ">>> Build complete."

if test $keepRunning -eq 1
    echo ">>> Containers kept running. You can stop them manually with: docker stop $backendName && docker rm $backendName"
else
    echo ">>> Cleaning up containers..."
    docker stop $backendName
    docker rm $backendName
    echo ">>> Done."
end

echo ">>> EPUBs are in the current directory."
