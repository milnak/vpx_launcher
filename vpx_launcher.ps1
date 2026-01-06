[CmdletBinding()]
Param(
    # Location to the VPinball EXE
    [string]$PinballExe = (Resolve-Path 'VPinballX64.exe'),
    # Folder containing VPX tables
    [string]$TablePath = (Resolve-Path 'Tables'),
    # Zero-based display number to use. Find numbers in Settings > System > Display
    [int]$Display = -1
)

$script:launcherVersion = '1.7.6'

$script:colorScheme = @{
    # "Ubuntu Custom"
    ListView_BackColor     = [Drawing.Color]::FromArgb(94, 92, 100) # Dark Gray
    ListView_ForeColor     = [Drawing.Color]::FromArgb(255, 255, 255) # White
    PanelStatus_BackColor  = [Drawing.Color]::FromArgb(23, 20, 33) # Very Dark Purple
    PanelStatus_ForeColor  = [Drawing.Color]::FromArgb(162, 115, 76) # Light Brown
    ProgressBar_BackColor  = [Drawing.Color]::FromArgb(23, 20, 33) # Very Dark Purple
    ProgressBar_ForeColor  = [Drawing.Color]::FromArgb(51, 218, 122) # Light Green
    ButtonLaunch_BackColor = [Drawing.Color]::FromArgb(18, 72, 139) # Dark Blue
    ButtonLaunch_ForeColor = [Drawing.Color]::FromArgb(208, 207, 204) # Light Gray
}

# SubItems index in listview
$script:colManufacturer = 1
$script:colYear = 2
$script:colDetails = 3
$script:colPlayCount = 4

# =============================================================================
# Global Variables

$script:metadataCache = @{}
$script:launchCount = @{}

# =============================================================================
# Table metadata

# To generate this lookup table:
# 1. Go to https://virtualpinballspreadsheet.github.io/export
# 2. Click the VPS logo
# 3. Click Filter button and choose Features > VPX
# 4. Click Tools > CSV Export
# 5. Click "Export CSV" to save as puplookup.csv
# 6. Run Get-PUPLookupTable function below to generate the lookup table.
# 7. Paste result below.
# 8. VSCode: Format document.
function Get-PUPLookupTable {
    '$script:puplookup = @{'
    # GameFileName, GameNAme, Manufact, GameYear can be imferred
    $data = Import-Csv .\puplookup.csv | Sort-Object -Unique GameName | Where-Object WebLinkURL -ne ''
    foreach ($entry in $data) {

        $rating = [double]0.0
        # Rating isn't in puplookup, so grab from IPDB if WebLinkUrl is present.
        # (commenting this out as scraping IPDB isn't permitted)
        $entry.WebLinkUrl = ''

        if ($entry.WebLinkUrl -ne '') {
            Write-Progress -Activity 'Fetching Rating' -Status $entry.GameName
            $prev = $global:ProgressPreference
            try {
                $global:ProgressPreference = 'SilentlyContinue'
                $result = Invoke-WebRequest -Uri $entry.WebLinkURL
            }
            catch {
                Write-Warning "Exception: '($entry.WebLinkUrl)': $($_.Exception.Message)"
            }
            finally {
                $global:ProgressPreference = $prev
            }
            if ($null -ne $result) {
                if ($result.StatusCode -eq 200) {
                    $html = $result.Content
                    if ($html -match '<b>Average Fun Rating: <\/b>.*<b>(?<rating>.+)<\/b>\/10') {
                        $rating = [double]$matches['rating']
                    }
                }
            }
        }

        # IPDBNum: "https://www.ipdb.org/machine.cgi?id=$IPDBNum"
        # TODO: quote single quotes in GameName, Theme. Put '1' if NumPlayers is missing.
        # TODO: put 0 if NumPlayers is missing.
        '    "{0}" =  @{{ IPDBNum = {1}; Players = {2}; Type = ''{3}''; Theme = ''{4}''; Rating = {5} }}' -f `
            $entry.GameName, $entry.IPDBNum, $entry.NumPlayers, $entry.GameType, $entry.GameTheme, $rating
    }
    '}'
}

$script:puplookup = @{
    "!WOW! (Mills Novelty Company 1932)"                                               = @{ IPDBNum = 2819; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "'300' (Gottlieb 1975)"                                                            = @{ IPDBNum = 2539; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.4 }
    "1-2-3 (Automaticos 1973)"                                                         = @{ IPDBNum = 5247; NumPlayers = 1; Type = 'EM'; Theme = 'TV Show, Game Show'; Rating = 0 }
    "2 in 1 (Bally 1964)"                                                              = @{ IPDBNum = 2698; NumPlayers = 2; Type = 'EM'; Theme = 'Cards'; Rating = 0 }
    "2001 (Gottlieb 1971)"                                                             = @{ IPDBNum = 2697; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.6 }
    "24 (Stern 2009)"                                                                  = @{ IPDBNum = 5419; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Crime'; Rating = 7 }
    "250 cc (Inder 1992)"                                                              = @{ IPDBNum = 4089; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Motorcycle Racing'; Rating = 0 }
    "3-In-Line (Bally 1963)"                                                           = @{ IPDBNum = 2549; NumPlayers = 4; Type = 'EM'; Theme = 'Majorettes'; Rating = 0 }
    "301 Bullseye (Grand Products 1986)"                                               = @{ IPDBNum = 403; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Darts'; Rating = 0 }
    "4 Aces (Williams 1970)"                                                           = @{ IPDBNum = 928; NumPlayers = 2; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.2 }
    "4 Queens (Bally 1970)"                                                            = @{ IPDBNum = 936; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Happiness'; Rating = 7.3 }
    "4 Roses (Williams 1962)"                                                          = @{ IPDBNum = 938; NumPlayers = 1; Type = 'EM'; Theme = 'Pageantry'; Rating = 7.8 }
    "4 Square (Gottlieb 1971)"                                                         = @{ IPDBNum = 940; NumPlayers = 1; Type = 'EM'; Theme = 'Dancing, Happiness, Music, Psychedelic'; Rating = 7.6 }
    "4X4 (Atari 1983)"                                                                 = @{ IPDBNum = 3111; NumPlayers = 4; Type = 'SS'; Theme = 'Cars'; Rating = 0 }
    "8 Ball (Williams 1966)"                                                           = @{ IPDBNum = 764; NumPlayers = 2; Type = 'EM'; Theme = 'Billiards'; Rating = 7.7 }
    "A-Go-Go (Williams 1966)"                                                          = @{ IPDBNum = 27; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Dancing'; Rating = 7.6 }
    "Aaron Spelling (Data East 1992)"                                                  = @{ IPDBNum = 4339; NumPlayers = 4; Type = 'SS'; Theme = 'TV Show, Celebrities'; Rating = 0 }
    "Abra Ca Dabra (Gottlieb 1975)"                                                    = @{ IPDBNum = 2; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy, Wizards, Magic'; Rating = 7.8 }
    "AC/DC (Let There Be Rock Limited Edition) (Stern 2012)"                           = @{ IPDBNum = 5776; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 7.9 }
    "AC/DC (LUCI Premium) (Stern 2013)"                                                = @{ IPDBNum = 6060; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 0 }
    "AC/DC (LUCI Vault Edition) (Stern 2018)"                                          = @{ IPDBNum = 6502; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 0 }
    "AC/DC (Premium) (Stern 2012)"                                                     = @{ IPDBNum = 5775; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 8 }
    "AC/DC (Pro Vault Edition) (Stern 2017)"                                           = @{ IPDBNum = 6439; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 0 }
    "AC/DC (Pro) (Stern 2012)"                                                         = @{ IPDBNum = 5767; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 7.9 }
    "AC/DC Back In Black (Limited Edition) (Stern 2012)"                               = @{ IPDBNum = 5777; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 7.8 }
    "Ace High (Gottlieb 1957)"                                                         = @{ IPDBNum = 7; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.6 }
    "Aces & Kings (Williams 1970)"                                                     = @{ IPDBNum = 11; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 6.4 }
    "Aces High (Bally 1965)"                                                           = @{ IPDBNum = 9; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling, Poker, Riverboat'; Rating = 0 }
    "Addams Family, The - B&W Edition (Bally 1992)"                                    = @{ IPDBNum = 20; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie'; Rating = 8.3 }
    "Addams Family, The (Bally 1992)"                                                  = @{ IPDBNum = 20; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie'; Rating = 8.3 }
    "Adventure (Sega 1979)"                                                            = @{ IPDBNum = 5544; NumPlayers = 2; Type = 'SS'; Theme = 'Adventure, Boats, Recreation, Sailing, Water'; Rating = 0 }
    "Adventures of Rocky and Bullwinkle and Friends (Data East 1993)"                  = @{ IPDBNum = 23; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Kids, TV Show, Licensed Theme'; Rating = 7.8 }
    "Aerobatics (Zaccaria 1977)"                                                       = @{ IPDBNum = 24; NumPlayers = 1; Type = 'EM'; Theme = 'Aviation'; Rating = 0 }
    "Aerosmith (Pro) (Stern 2017)"                                                     = @{ IPDBNum = 6370; NumPlayers = 4; Type = 'SS'; Theme = 'Music'; Rating = 7.9 }
    "Agents 777 (Game Plan 1984)"                                                      = @{ IPDBNum = 26; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Crime'; Rating = 0 }
    "Air Aces (Bally 1975)"                                                            = @{ IPDBNum = 28; NumPlayers = 4; Type = 'EM'; Theme = 'Adventure, Aviation, Combat'; Rating = 6.6 }
    "Airborne (Capcom 1996)"                                                           = @{ IPDBNum = 3783; NumPlayers = 4; Type = 'SS'; Theme = 'Aviation'; Rating = 7.5 }
    "Airborne (J. Esteban 1979)"                                                       = @{ IPDBNum = 5133; NumPlayers = 4; Type = 'EM'; Theme = 'Aviation'; Rating = 0 }
    "Airborne Avenger (Atari 1977)"                                                    = @{ IPDBNum = 33; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Combat, Aviation'; Rating = 0 }
    "Airport (Gottlieb 1969)"                                                          = @{ IPDBNum = 35; NumPlayers = 2; Type = 'EM'; Theme = 'Travel'; Rating = 6.2 }
    "Al Capone (LTD do Brasil 1984)"                                                   = @{ IPDBNum = 5176; NumPlayers = 4; Type = 'SS'; Theme = 'American History, Cards, Gambling, Crime, Mobsters'; Rating = 0 }
    "Al's Garage Band Goes on a World Tour (Alvin G. 1992)"                            = @{ IPDBNum = 3513; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Singing'; Rating = 6.7 }
    "Aladdin's Castle (Bally 1976)"                                                    = @{ IPDBNum = 40; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy, Mythology'; Rating = 7.6 }
    "Alaska (Interflip 1978)"                                                          = @{ IPDBNum = 3888; NumPlayers = 4; Type = 'SS'; Theme = 'American Places'; Rating = 0 }
    "Algar (Williams 1980)"                                                            = @{ IPDBNum = 42; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.1 }
    "Ali (Stern 1980)"                                                                 = @{ IPDBNum = 43; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Boxing, Licensed Theme'; Rating = 7.4 }
    "Alice in Wonderland (Gottlieb 1948)"                                              = @{ IPDBNum = 47; NumPlayers = 1; Type = 'EM'; Theme = 'Fictional Characters'; Rating = 0 }
    "Alien Poker (Williams 1980)"                                                      = @{ IPDBNum = 48; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Outer Space, Cards, Gambling'; Rating = 7.7 }
    "Alien Star (Gottlieb 1984)"                                                       = @{ IPDBNum = 49; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Alien Warrior (LTD do Brasil 1982)"                                               = @{ IPDBNum = 5882; NumPlayers = 4; Type = 'SS'; Theme = 'Aliens, Fantasy, Outer Space'; Rating = 0 }
    "Alive (Brunswick 1978)"                                                           = @{ IPDBNum = 50; NumPlayers = 4; Type = 'SS'; Theme = 'Music'; Rating = 0 }
    "Aloha (Gottlieb 1961)"                                                            = @{ IPDBNum = 62; NumPlayers = 2; Type = 'EM'; Theme = 'American Places, Hawaii'; Rating = 7.5 }
    "Amazing Spider-Man, The - Sinister Six Edition (Gottlieb 1980)"                   = @{ IPDBNum = 2285; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Superheroes'; Rating = 7.5 }
    "Amazing Spider-Man, The (Gottlieb 1980)"                                          = @{ IPDBNum = 2285; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Superheroes'; Rating = 7.5 }
    "Amazon Hunt (Gottlieb 1983)"                                                      = @{ IPDBNum = 66; NumPlayers = 4; Type = 'SS'; Theme = 'Hunting, Jungle'; Rating = 7.4 }
    "America 1492 (Juegos Populares 1986)"                                             = @{ IPDBNum = 5013; NumPlayers = 4; Type = 'SS'; Theme = 'Historical'; Rating = 0 }
    "America's Most Haunted (Spooky Pinball 2014)"                                     = @{ IPDBNum = 6161; NumPlayers = 4; Type = 'SS'; Theme = 'Horror, Supernatural'; Rating = 7.4 }
    "Amigo (Bally 1974)"                                                               = @{ IPDBNum = 71; NumPlayers = 4; Type = 'EM'; Theme = 'Dancing, Happiness, Music, Singing, World Culture'; Rating = 7.8 }
    "Andromeda - Tokyo 2074 Edition (Game Plan 1985)"                                  = @{ IPDBNum = 73; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Women'; Rating = 7.1 }
    "Andromeda (Game Plan 1985)"                                                       = @{ IPDBNum = 73; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Women'; Rating = 7.1 }
    "Antar (Playmatic 1979)"                                                           = @{ IPDBNum = 3646; NumPlayers = 4; Type = 'SS'; Theme = 'Dragons, Fantasy'; Rating = 0 }
    "Apache (Playmatic 1975)"                                                          = @{ IPDBNum = 4483; NumPlayers = 1; Type = 'EM'; Theme = 'Crime, Women, Adult'; Rating = 0 }
    "Apache! (Taito do Brasil 1978)"                                                   = @{ IPDBNum = 4660; NumPlayers = 4; Type = 'EM'; Theme = 'American West, Native Americans, Warriors'; Rating = 0 }
    "Apollo (Williams 1967)"                                                           = @{ IPDBNum = 77; NumPlayers = 1; Type = 'EM'; Theme = 'Space Exploration'; Rating = 7.8 }
    "Apollo 13 (Sega 1995)"                                                            = @{ IPDBNum = 3592; NumPlayers = 6; Type = 'SS'; Theme = 'Outer Space, Movie, Astronauts, Licensed Theme'; Rating = 7.8 }
    "Aqualand (Juegos Populares 1986)"                                                 = @{ IPDBNum = 3935; NumPlayers = 4; Type = 'SS'; Theme = 'Amusement Park, Aquatic'; Rating = 0 }
    "Aquarius (Gottlieb 1970)"                                                         = @{ IPDBNum = 79; NumPlayers = 1; Type = 'EM'; Theme = 'Astrology'; Rating = 7.6 }
    "Arena (Gottlieb 1987)"                                                            = @{ IPDBNum = 82; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.1 }
    "Argosy (Williams 1977)"                                                           = @{ IPDBNum = 84; NumPlayers = 4; Type = 'EM'; Theme = 'Boats, Nautical, Ships, Aquatic'; Rating = 6.6 }
    "Arizona (LTD do Brasil 1977)"                                                     = @{ IPDBNum = 5890; NumPlayers = 2; Type = 'SS'; Theme = 'American West'; Rating = 0 }
    "Aspen (Brunswick 1979)"                                                           = @{ IPDBNum = 3660; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Skiing'; Rating = 0 }
    "Asteroid Annie and the Aliens (Gottlieb 1980)"                                    = @{ IPDBNum = 98; NumPlayers = 1; Type = 'SS'; Theme = 'Science Fiction, Outer Space, Cards, Gambling, Aliens'; Rating = 7.1 }
    "Astro (Gottlieb 1971)"                                                            = @{ IPDBNum = 99; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space'; Rating = 8 }
    "Astronaut (Chicago Coin 1969)"                                                    = @{ IPDBNum = 101; NumPlayers = 2; Type = 'EM'; Theme = 'Astronauts, Outer Space'; Rating = 0 }
    "Atarians, The (Atari 1976)"                                                       = @{ IPDBNum = 102; NumPlayers = 1; Type = 'SS'; Theme = 'Adventure'; Rating = 0 }
    "Atlantis (Bally 1989)"                                                            = @{ IPDBNum = 106; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology, Aquatic'; Rating = 7.3 }
    "Atlantis (Gottlieb 1975)"                                                         = @{ IPDBNum = 105; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy, Mythology'; Rating = 7.7 }
    "Atlantis (LTD do Brasil 1978)"                                                    = @{ IPDBNum = 6712; NumPlayers = 2; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Atleta (Inder 1991)"                                                              = @{ IPDBNum = 4095; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Olympic Games'; Rating = 0 }
    "Attack from Mars (Bally 1995)"                                                    = @{ IPDBNum = 3781; NumPlayers = 4; Type = 'SS'; Theme = 'Aliens, Martians, Fantasy'; Rating = 8.2 }
    "Attila the Hun (Game Plan 1984)"                                                  = @{ IPDBNum = 109; NumPlayers = 4; Type = 'SS'; Theme = 'Historical'; Rating = 0 }
    "Austin Powers (Stern 2001)"                                                       = @{ IPDBNum = 4504; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie'; Rating = 6.7 }
    "Avengers (Pro), The (Stern 2012)"                                                 = @{ IPDBNum = 5938; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes, Movie'; Rating = 6.4 }
    "Aztec - High-Tap Edition (Williams 1976)"                                         = @{ IPDBNum = 119; NumPlayers = 4; Type = 'EM'; Theme = 'Historical, World Places'; Rating = 7.8 }
    "Aztec (Williams 1976)"                                                            = @{ IPDBNum = 119; NumPlayers = 4; Type = 'EM'; Theme = 'Historical, World Places'; Rating = 7.8 }
    "Baby Leland (Stoner 1933)"                                                        = @{ IPDBNum = 123; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Baby Pac-Man (Bally 1982)"                                                        = @{ IPDBNum = 125; NumPlayers = 2; Type = 'SS'; Theme = 'Video Game'; Rating = 6.9 }
    "Back to the Future (Data East 1990)"                                              = @{ IPDBNum = 126; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Time Travel, Movie'; Rating = 7.6 }
    "Bad Cats (Williams 1989)"                                                         = @{ IPDBNum = 127; NumPlayers = 4; Type = 'SS'; Theme = 'Feline Mischief'; Rating = 7.8 }
    "Bad Girls - Alternate Edition (Gottlieb 1988)"                                    = @{ IPDBNum = 128; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 6.6 }
    "Bad Girls - Tooned-Up Version (Gottlieb 1988)"                                    = @{ IPDBNum = 128; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 6.6 }
    "Bad Girls (Gottlieb 1988)"                                                        = @{ IPDBNum = 128; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 6.6 }
    "Balls-A-Poppin (Bally 1956)"                                                      = @{ IPDBNum = 144; NumPlayers = 2; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 0 }
    "Bally Game Show, The (Bally 1990)"                                                = @{ IPDBNum = 985; NumPlayers = 4; Type = 'SS'; Theme = 'Comedy, Game Show'; Rating = 7.1 }
    "Bally Hoo (Bally 1969)"                                                           = @{ IPDBNum = 151; NumPlayers = 4; Type = 'EM'; Theme = 'Circus, Carnival, Music'; Rating = 7.5 }
    "Ballyhoo (Bally 1932)"                                                            = @{ IPDBNum = 4817; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Band Wagon (Bally 1965)"                                                          = @{ IPDBNum = 163; NumPlayers = 4; Type = 'EM'; Theme = 'Circus, Carnival'; Rating = 0 }
    "Bank Shot (Gottlieb 1976)"                                                        = @{ IPDBNum = 169; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 7.4 }
    "Bank-A-Ball (Gottlieb 1965)"                                                      = @{ IPDBNum = 170; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 7.5 }
    "Bank-A-Ball (J.F. Linck 1932)"                                                    = @{ IPDBNum = 6520; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Banzai Run (Williams 1988)"                                                       = @{ IPDBNum = 175; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross'; Rating = 7.8 }
    "Barb Wire (Gottlieb 1996)"                                                        = @{ IPDBNum = 3795; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie, Motorcycles'; Rating = 7.3 }
    "Barbarella (Automaticos 1972)"                                                    = @{ IPDBNum = 5809; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy, Outer Space, Science Fiction, Movie'; Rating = 0 }
    "Barracora (Williams 1981)"                                                        = @{ IPDBNum = 177; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.5 }
    "Baseball (Gottlieb 1970)"                                                         = @{ IPDBNum = 185; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.4 }
    "Basketball (IDSA 1986)"                                                           = @{ IPDBNum = 5023; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball'; Rating = 0 }
    "Bat-Em (In & Outdoor 1932)"                                                       = @{ IPDBNum = 194; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Batman (66 Premium) (Stern 2016)"                                                 = @{ IPDBNum = 6354; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Licensed Theme, Superheroes'; Rating = 8.7 }
    "Batman (Data East 1991)"                                                          = @{ IPDBNum = 195; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Licensed Theme, Superheroes, Movie'; Rating = 7.2 }
    "Batman (Stern 2008)"                                                              = @{ IPDBNum = 5307; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Superheroes, Comics'; Rating = 8 }
    "Batman Forever (Sega 1995)"                                                       = @{ IPDBNum = 3593; NumPlayers = 6; Type = 'SS'; Theme = 'Comics, Licensed Theme, Superheroes, Movie'; Rating = 7.8 }
    "Batter Up (Gottlieb 1970)"                                                        = @{ IPDBNum = 197; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.6 }
    "Baywatch (Sega 1995)"                                                             = @{ IPDBNum = 2848; NumPlayers = 6; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, TV Show'; Rating = 7.9 }
    "Beat the Clock (Bally 1985)"                                                      = @{ IPDBNum = 212; NumPlayers = 4; Type = 'SS'; Theme = 'Sports'; Rating = 0 }
    "Beat Time - Beatles Edition (Williams 1967)"                                      = @{ IPDBNum = 213; NumPlayers = 2; Type = 'EM'; Theme = 'Happiness, Music'; Rating = 5.8 }
    "Beat Time (Williams 1967)"                                                        = @{ IPDBNum = 213; NumPlayers = 2; Type = 'EM'; Theme = 'Happiness, Music'; Rating = 5.8 }
    "Beisbol (Maresa 1971)"                                                            = @{ IPDBNum = 5320; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 0 }
    "Bell Ringer (Gottlieb 1990)"                                                      = @{ IPDBNum = 3602; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross'; Rating = 0 }
    "Ben Hur (Staal 1977)"                                                             = @{ IPDBNum = 2855; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional Characters, World Places'; Rating = 0 }
    "Big Bang Bar (Capcom 1996)"                                                       = @{ IPDBNum = 4001; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Aliens'; Rating = 7.3 }
    "Big Ben (Williams 1975)"                                                          = @{ IPDBNum = 232; NumPlayers = 1; Type = 'EM'; Theme = 'World Places, Landmarks'; Rating = 6.1 }
    "Big Brave - B&W Edition (Gottlieb 1974)"                                          = @{ IPDBNum = 234; NumPlayers = 2; Type = 'EM'; Theme = 'American West, Native Americans'; Rating = 7.6 }
    "Big Brave (Gottlieb 1974)"                                                        = @{ IPDBNum = 234; NumPlayers = 2; Type = 'EM'; Theme = 'American West, Native Americans'; Rating = 7.6 }
    "Big Brave (Maresa 1974)"                                                          = @{ IPDBNum = 4634; NumPlayers = 2; Type = 'EM'; Theme = 'American West, Native Americans'; Rating = 7.5 }
    "Big Buck Hunter Pro (Stern 2010)"                                                 = @{ IPDBNum = 5513; NumPlayers = 4; Type = 'SS'; Theme = 'Hunting, Licensed Theme'; Rating = 6.7 }
    "Big Casino (Gottlieb 1961)"                                                       = @{ IPDBNum = 239; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Cards'; Rating = 6.7 }
    "Big Chief (Williams 1965)"                                                        = @{ IPDBNum = 240; NumPlayers = 4; Type = 'EM'; Theme = 'Native Americans'; Rating = 7.3 }
    "Big Deal (Williams 1963)"                                                         = @{ IPDBNum = 244; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.4 }
    "Big Deal (Williams 1977)"                                                         = @{ IPDBNum = 245; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.3 }
    "Big Dick - Orphaned on vpinball.com (Fabulous Fantasies 1996)"                    = @{ IPDBNum = 4539; NumPlayers = 1; Type = 'EM'; Theme = 'Adult'; Rating = 0 }
    "Big Dick (Fabulous Fantasies 1996)"                                               = @{ IPDBNum = 4539; NumPlayers = 1; Type = 'EM'; Theme = 'Adult'; Rating = 0 }
    "Big Game (Rock-ola 1935)"                                                         = @{ IPDBNum = 248; NumPlayers = 1; Type = 'PM'; Theme = 'Sports, Hunting'; Rating = 0 }
    "Big Game (Stern 1980)"                                                            = @{ IPDBNum = 249; NumPlayers = 4; Type = 'SS'; Theme = 'Hunting, Safari'; Rating = 7.3 }
    "Big Guns (Williams 1987)"                                                         = @{ IPDBNum = 250; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 7.1 }
    "Big Hit (Gottlieb 1977)"                                                          = @{ IPDBNum = 253; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.3 }
    "Big Horse (Maresa 1975)"                                                          = @{ IPDBNum = 255; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy'; Rating = 0 }
    "Big House (Gottlieb 1989)"                                                        = @{ IPDBNum = 256; NumPlayers = 4; Type = 'SS'; Theme = 'Crime, Police'; Rating = 7.3 }
    "Big Indian (Gottlieb 1974)"                                                       = @{ IPDBNum = 257; NumPlayers = 4; Type = 'EM'; Theme = 'American West, Native Americans'; Rating = 7.8 }
    "Big Injun (Gottlieb 1974)"                                                        = @{ IPDBNum = 257; NumPlayers = 4; Type = 'EM'; Theme = 'Native Americans, American West'; Rating = 7.8 }
    "Big Shot (Gottlieb 1974)"                                                         = @{ IPDBNum = 271; NumPlayers = 2; Type = 'EM'; Theme = 'Billiards'; Rating = 7.3 }
    "Big Show (Bally 1974)"                                                            = @{ IPDBNum = 275; NumPlayers = 2; Type = 'EM'; Theme = 'Circus, Carnival'; Rating = 5.7 }
    "Big Star (Williams 1972)"                                                         = @{ IPDBNum = 279; NumPlayers = 1; Type = 'EM'; Theme = 'Music'; Rating = 0 }
    "Big Top (Gottlieb 1988)"                                                          = @{ IPDBNum = 5347; NumPlayers = 4; Type = 'SS'; Theme = 'Circus, Carnival'; Rating = 0 }
    "Big Town (Playmatic 1978)"                                                        = @{ IPDBNum = 3607; NumPlayers = 4; Type = 'SS'; Theme = 'City Skyline'; Rating = 0 }
    "Big Valley (Bally 1970)"                                                          = @{ IPDBNum = 289; NumPlayers = 4; Type = 'EM'; Theme = 'American West'; Rating = 7.7 }
    "Black & Red (Inder 1975)"                                                         = @{ IPDBNum = 4413; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Black Belt (Bally 1986)"                                                          = @{ IPDBNum = 303; NumPlayers = 4; Type = 'SS'; Theme = 'Martial Arts'; Rating = 0 }
    "Black Fever (Playmatic 1980)"                                                     = @{ IPDBNum = 3645; NumPlayers = 4; Type = 'SS'; Theme = 'Dancing, Music, Women'; Rating = 0 }
    "Black Gold (Williams 1975)"                                                       = @{ IPDBNum = 306; NumPlayers = 1; Type = 'EM'; Theme = 'American History'; Rating = 0 }
    "Black Hole (Gottlieb 1981)"                                                       = @{ IPDBNum = 307; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.8 }
    "Black Hole (LTD do Brasil 1982)"                                                  = @{ IPDBNum = 5891; NumPlayers = 2; Type = 'SS'; Theme = 'Outer Space, Space Fantasy'; Rating = 0 }
    "Black Jack (SS) (Bally 1978)"                                                     = @{ IPDBNum = 309; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 7.3 }
    "Black Knight (Williams 1980)"                                                     = @{ IPDBNum = 310; NumPlayers = 4; Type = 'SS'; Theme = 'Medieval, Knights'; Rating = 8 }
    "Black Knight 2000 (Williams 1989)"                                                = @{ IPDBNum = 311; NumPlayers = 4; Type = 'SS'; Theme = 'Medieval, Knights'; Rating = 7.9 }
    "Black Knight Sword of Rage (Stern 2019)"                                          = @{ IPDBNum = 6569; NumPlayers = 4; Type = 'SS'; Theme = 'Medieval, Knights'; Rating = 0 }
    "Black Magic 4 (Recel 1980)"                                                       = @{ IPDBNum = 3626; NumPlayers = 4; Type = 'SS'; Theme = 'Occult, Black Magic'; Rating = 0 }
    "Black Pyramid (Bally 1984)"                                                       = @{ IPDBNum = 312; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Supernatural'; Rating = 6.8 }
    "Black Rose (Bally 1992)"                                                          = @{ IPDBNum = 313; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Pirates, Fictional'; Rating = 8 }
    "Black Sheep Squadron (Astro Games 1979)"                                          = @{ IPDBNum = 314; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Combat'; Rating = 0 }
    "Black Velvet (Game Plan 1978)"                                                    = @{ IPDBNum = 315; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme'; Rating = 0 }
    "Blackout (Williams 1980)"                                                         = @{ IPDBNum = 317; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Space Fantasy'; Rating = 7.6 }
    "Blackwater 100 (Bally 1988)"                                                      = @{ IPDBNum = 319; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross'; Rating = 6.7 }
    "Blue Chip (Williams 1976)"                                                        = @{ IPDBNum = 325; NumPlayers = 1; Type = 'EM'; Theme = 'Stock Market'; Rating = 7.5 }
    "Blue Note (Gottlieb 1978)"                                                        = @{ IPDBNum = 328; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing'; Rating = 7.3 }
    "BMX - RAD Edition (Bally 1983)"                                                   = @{ IPDBNum = 335; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Bicycling'; Rating = 0 }
    "BMX - Radical Rick Edition (Bally 1983)"                                          = @{ IPDBNum = 335; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Bicycling'; Rating = 0 }
    "BMX (Bally 1983)"                                                                 = @{ IPDBNum = 335; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Bicycling'; Rating = 0 }
    "Bobby Orr Power Play (Bally 1978)"                                                = @{ IPDBNum = 1858; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Hockey, Celebrities'; Rating = 7.5 }
    "Bon Voyage (Bally 1974)"                                                          = @{ IPDBNum = 343; NumPlayers = 1; Type = 'EM'; Theme = 'Aviation, Travel, Transportation'; Rating = 7 }
    "Bone Busters Inc. (Gottlieb 1989)"                                                = @{ IPDBNum = 347; NumPlayers = 4; Type = 'SS'; Theme = 'Horror, Supernatural'; Rating = 7.3 }
    "Boomerang (Bally 1974)"                                                           = @{ IPDBNum = 354; NumPlayers = 4; Type = 'EM'; Theme = 'Adventure, World Culture'; Rating = 7.6 }
    "Boop-A-Doop (Pace 1932)"                                                          = @{ IPDBNum = 3653; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Border Town (Gottlieb 1940)"                                                      = @{ IPDBNum = 357; NumPlayers = 1; Type = 'EM'; Theme = 'American History, American West'; Rating = 0 }
    "Bounty Hunter (Gottlieb 1985)"                                                    = @{ IPDBNum = 361; NumPlayers = 4; Type = 'SS'; Theme = 'American West'; Rating = 7.1 }
    "Bow and Arrow (EM) (Bally 1975)"                                                  = @{ IPDBNum = 362; NumPlayers = 4; Type = 'EM'; Theme = 'American West, Native Americans'; Rating = 7.6 }
    "Bow and Arrow (SS) (Bally 1974)"                                                  = @{ IPDBNum = 4770; NumPlayers = 4; Type = 'SS'; Theme = 'American West, Native Americans'; Rating = 0 }
    "Bowling - Alle Neune (NSM 1976)"                                                  = @{ IPDBNum = 6037; NumPlayers = 1; Type = 'EM'; Theme = 'Bowling, Sports'; Rating = 0 }
    "Bram Stoker's Dracula - Blood Edition (Williams 1993)"                            = @{ IPDBNum = 3072; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Fictional, Horror, Supernatural, Movie'; Rating = 8.1 }
    "Bram Stoker's Dracula (Williams 1993)"                                            = @{ IPDBNum = 3072; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Fictional, Horror, Supernatural, Movie'; Rating = 8.1 }
    "Brave Team (Inder 1985)"                                                          = @{ IPDBNum = 4480; NumPlayers = 4; Type = 'SS'; Theme = 'Motorcycles'; Rating = 0 }
    "Break (Video Dens 1986)"                                                          = @{ IPDBNum = 5569; NumPlayers = 4; Type = 'SS'; Theme = 'Dancing'; Rating = 0 }
    "Breakshot (Capcom 1996)"                                                          = @{ IPDBNum = 3784; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Billiards'; Rating = 7.3 }
    "Bristol Hills (Gottlieb 1971)"                                                    = @{ IPDBNum = 376; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Skiing, Snowmobiling'; Rating = 0 }
    "Bronco (Gottlieb 1977)"                                                           = @{ IPDBNum = 388; NumPlayers = 4; Type = 'EM'; Theme = 'American West'; Rating = 7.4 }
    "Buccaneer (Gottlieb 1948)"                                                        = @{ IPDBNum = 390; NumPlayers = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical'; Rating = 0 }
    "Buccaneer (Gottlieb 1976)"                                                        = @{ IPDBNum = 391; NumPlayers = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical'; Rating = 7.6 }
    "Buccaneer (J. Esteban 1976)"                                                      = @{ IPDBNum = 6276; NumPlayers = 4; Type = 'EM'; Theme = 'Adventure, Pirates'; Rating = 0 }
    "Buck Rogers (Gottlieb 1980)"                                                      = @{ IPDBNum = 392; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Outer Space, TV Show'; Rating = 7.3 }
    "Buckaroo (Gottlieb 1965)"                                                         = @{ IPDBNum = 393; NumPlayers = 1; Type = 'EM'; Theme = 'American West'; Rating = 7.8 }
    "Bugs Bunny's Birthday Ball (Bally 1990)"                                          = @{ IPDBNum = 396; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Cartoon, Happiness, Kids'; Rating = 6.9 }
    "Bumper - B&W Edition (Bill Port 1977)"                                            = @{ IPDBNum = 6194; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Science Fiction, Space Fantasy'; Rating = 0 }
    "Bumper (Bill Port 1977)"                                                          = @{ IPDBNum = 6194; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Science Fiction, Space Fantasy'; Rating = 0 }
    "Bumper Pool (Gottlieb 1969)"                                                      = @{ IPDBNum = 406; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 0 }
    "Bunnyboard (Marble Games 1932)"                                                   = @{ IPDBNum = 407; NumPlayers = 0; Type = 'EM'; Theme = 'Flipperless'; Rating = 0 }
    "Bushido (Inder 1993)"                                                             = @{ IPDBNum = 4481; NumPlayers = 4; Type = 'SS'; Theme = 'World Culture'; Rating = 0 }
    "Cabaret (Williams 1968)"                                                          = @{ IPDBNum = 415; NumPlayers = 4; Type = 'EM'; Theme = 'Dancing, Happiness, Music, Nightlife, Singing'; Rating = 0 }
    "Cactus Canyon (Bally 1998)"                                                       = @{ IPDBNum = 4445; NumPlayers = 4; Type = 'SS'; Theme = 'American West'; Rating = 8 }
    "Cactus Jack's (Gottlieb 1991)"                                                    = @{ IPDBNum = 416; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Singing, Dancing, Comedy, Country and Western'; Rating = 7.3 }
    "Caddie (Playmatic 1970)"                                                          = @{ IPDBNum = 417; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Golf'; Rating = 0 }
    "Canada Dry (Gottlieb 1976)"                                                       = @{ IPDBNum = 426; NumPlayers = 4; Type = 'EM'; Theme = 'Licensed Theme, Drinking'; Rating = 7.3 }
    "Canasta 86 (Inder 1986)"                                                          = @{ IPDBNum = 4097; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball'; Rating = 0 }
    "Cannes (Segasa 1976)"                                                             = @{ IPDBNum = 428; NumPlayers = 4; Type = 'EM'; Theme = 'World Places, Aquatic, Sports, Happiness, Recreation, Water Skiing, Swimming'; Rating = 0 }
    "Capersville (Bally 1966)"                                                         = @{ IPDBNum = 431; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.4 }
    "Capt. Card (Gottlieb 1974)"                                                       = @{ IPDBNum = 433; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.7 }
    "Capt. Fantastic and the Brown Dirt Cowboy (Bally 1976)"                           = @{ IPDBNum = 438; NumPlayers = 4; Type = 'EM'; Theme = 'Celebrities, Fictional, Licensed Theme'; Rating = 7.7 }
    "Captain NEMO Dives Again - Steampunk Flyer Edition (Quetzal Pinball 2015)"        = @{ IPDBNum = 6465; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional Characters'; Rating = 0 }
    "Captain NEMO Dives Again (Quetzal Pinball 2015)"                                  = @{ IPDBNum = 6465; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional Characters'; Rating = 0 }
    "Car Hop (Gottlieb 1991)"                                                          = @{ IPDBNum = 3676; NumPlayers = 4; Type = 'SS'; Theme = 'Cars, Food'; Rating = 7.6 }
    "Card King (Gottlieb 1971)"                                                        = @{ IPDBNum = 445; NumPlayers = 1; Type = 'EM'; Theme = 'Playing Cards'; Rating = 0 }
    "Card Trix (Gottlieb 1970)"                                                        = @{ IPDBNum = 446; NumPlayers = 1; Type = 'EM'; Theme = 'College Life, Happiness, Music, Cards'; Rating = 7.5 }
    "Card Whiz (Gottlieb 1976)"                                                        = @{ IPDBNum = 447; NumPlayers = 2; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "Carnival Queen (Bally 1958)"                                                      = @{ IPDBNum = 456; NumPlayers = 1; Type = 'EM'; Theme = 'Carnival, Happiness'; Rating = 0 }
    "Casino (Williams 1958)"                                                           = @{ IPDBNum = 463; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling'; Rating = 0 }
    "Catacomb (Stern 1981)"                                                            = @{ IPDBNum = 469; NumPlayers = 4; Type = 'SS'; Theme = 'Horror'; Rating = 7.4 }
    "Cavalcade (Stoner 1935)"                                                          = @{ IPDBNum = 473; NumPlayers = 1; Type = 'EM'; Theme = 'Horse Racing, Flipperless'; Rating = 0 }
    "Cavaleiro Negro (Taito do Brasil 1980)"                                           = @{ IPDBNum = 4568; NumPlayers = 4; Type = 'SS'; Theme = 'Medieval, Knights'; Rating = 0 }
    "Cavalier (Recel 1979)"                                                            = @{ IPDBNum = 474; NumPlayers = 4; Type = 'SS'; Theme = 'Historical Characters'; Rating = 0 }
    "Caveman (Gottlieb 1982)"                                                          = @{ IPDBNum = 475; NumPlayers = 4; Type = 'SS'; Theme = 'Historical'; Rating = 6.5 }
    "Centaur (Bally 1981)"                                                             = @{ IPDBNum = 476; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Motorcycles'; Rating = 8 }
    "Centigrade 37 (Gottlieb 1977)"                                                    = @{ IPDBNum = 480; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy, Science Fiction'; Rating = 7.8 }
    "Central Park (Gottlieb 1966)"                                                     = @{ IPDBNum = 481; NumPlayers = 1; Type = 'EM'; Theme = 'American Places'; Rating = 7.7 }
    "Cerberus (Playmatic 1983)"                                                        = @{ IPDBNum = 3004; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Champ (Bally 1974)"                                                               = @{ IPDBNum = 486; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Pinball'; Rating = 6.7 }
    "Champion Pub, The (Bally 1998)"                                                   = @{ IPDBNum = 4358; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Boxing'; Rating = 7.8 }
    "Chance (Playmatic 1974)"                                                          = @{ IPDBNum = 4878; NumPlayers = 1; Type = 'EM'; Theme = 'Magic, Witchcraft'; Rating = 0 }
    "Chance (Playmatic 1978)"                                                          = @{ IPDBNum = 491; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival'; Rating = 0 }
    "Charlie's Angels (Gottlieb 1978)"                                                 = @{ IPDBNum = 492; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show'; Rating = 6.5 }
    "Charlie's Angels (Gottlieb 1979)"                                                 = @{ IPDBNum = 5007; NumPlayers = 4; Type = 'EM'; Theme = 'Licensed Theme, TV Show, Women'; Rating = 0 }
    "Check (Recel 1975)"                                                               = @{ IPDBNum = 495; NumPlayers = 2; Type = 'EM'; Theme = 'Chess'; Rating = 0 }
    "Check Mate (Recel 1975)"                                                          = @{ IPDBNum = 496; NumPlayers = 4; Type = 'EM'; Theme = 'Chess'; Rating = 0 }
    "Check Mate (Taito do Brasil 1977)"                                                = @{ IPDBNum = 5491; NumPlayers = 4; Type = 'EM'; Theme = 'Board Games'; Rating = 0 }
    "Checkpoint (Data East 1991)"                                                      = @{ IPDBNum = 498; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 7 }
    "Cheetah (Stern 1980)"                                                             = @{ IPDBNum = 500; NumPlayers = 4; Type = 'SS'; Theme = 'Jungle, Fantasy'; Rating = 7.4 }
    "Chicago Cubs 'Triple Play' (Gottlieb 1985)"                                       = @{ IPDBNum = 502; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Baseball'; Rating = 6.9 }
    "Circus (Bally 1973)"                                                              = @{ IPDBNum = 521; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 6.4 }
    "Circus (Brunswick 1980)"                                                          = @{ IPDBNum = 4937; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival'; Rating = 0 }
    "Circus (Gottlieb 1980)"                                                           = @{ IPDBNum = 515; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival'; Rating = 7.2 }
    "Circus (Zaccaria 1977)"                                                           = @{ IPDBNum = 518; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 7.1 }
    "Cirqus Voltaire (Bally 1997)"                                                     = @{ IPDBNum = 4059; NumPlayers = 4; Type = 'SS'; Theme = 'Circus, Carnival'; Rating = 8.1 }
    "City Ship (J. Esteban 1978)"                                                      = @{ IPDBNum = 5130; NumPlayers = 2; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "City Slicker (Bally 1987)"                                                        = @{ IPDBNum = 527; NumPlayers = 4; Type = 'SS'; Theme = 'Crime, Mobsters, Police'; Rating = 0 }
    "Clash, The (Original 2018)"                                                       = @{ IPDBNum = 1979; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Singing'; Rating = 0 }
    "Class of 1812 (Gottlieb 1991)"                                                    = @{ IPDBNum = 528; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Supernatural'; Rating = 7.8 }
    "Cleopatra (SS) (Gottlieb 1977)"                                                   = @{ IPDBNum = 532; NumPlayers = 4; Type = 'SS'; Theme = 'Historical'; Rating = 7.4 }
    "Close Encounters of the Third Kind (Gottlieb 1978)"                               = @{ IPDBNum = 536; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Science Fiction'; Rating = 7 }
    "Clown (Inder 1988)"                                                               = @{ IPDBNum = 4093; NumPlayers = 4; Type = 'SS'; Theme = 'Circus, Carnival, Clowns'; Rating = 0 }
    "Clown (Playmatic 1971)"                                                           = @{ IPDBNum = 5447; NumPlayers = 1; Type = 'EM'; Theme = 'Circus, Carnival, Clowns'; Rating = 0 }
    "Cobra (Nuova Bell Games 1987)"                                                    = @{ IPDBNum = 3026; NumPlayers = 4; Type = 'SS'; Theme = 'Cops and Robbers'; Rating = 0 }
    "Cobra (Playbar 1987)"                                                             = @{ IPDBNum = 4124; NumPlayers = 4; Type = 'SS'; Theme = 'Cops and Robbers'; Rating = 0 }
    "College Queens (Gottlieb 1969)"                                                   = @{ IPDBNum = 543; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, School, Women'; Rating = 6.2 }
    "Columbia (LTD do Brasil 1983)"                                                    = @{ IPDBNum = 5759; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Exploration'; Rating = 0 }
    "Combination Rotation (Gottlieb 1982)"                                             = @{ IPDBNum = 5331; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Comet (Williams 1985)"                                                            = @{ IPDBNum = 548; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Amusement Park, Roller Coasters'; Rating = 7.7 }
    "Conan (Rowamet 1983)"                                                             = @{ IPDBNum = 4580; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie'; Rating = 0 }
    "Concorde (Emagar 1975)"                                                           = @{ IPDBNum = 6024; NumPlayers = 1; Type = 'EM'; Theme = 'Aircraft, Aviation, Historical, Travel'; Rating = 0 }
    "Congo (Williams 1995)"                                                            = @{ IPDBNum = 3780; NumPlayers = 4; Type = 'SS'; Theme = 'Jungle, Movie, Licensed Theme'; Rating = 8 }
    "Conquest 200 (Playmatic 1976)"                                                    = @{ IPDBNum = 557; NumPlayers = 1; Type = 'EM'; Theme = 'Historical'; Rating = 0 }
    "Contact (Williams 1978)"                                                          = @{ IPDBNum = 558; NumPlayers = 4; Type = 'SS'; Theme = 'Aliens, Fantasy, Outer Space'; Rating = 7.1 }
    "Contact Master (PAMCO 1934)"                                                      = @{ IPDBNum = 4457; NumPlayers = 1; Type = 'EM'; Theme = 'Flipperless'; Rating = 0 }
    "Contest (Gottlieb 1958)"                                                          = @{ IPDBNum = 564; NumPlayers = 4; Type = 'EM'; Theme = 'Pinball'; Rating = 0 }
    "Coronation (Gottlieb 1952)"                                                       = @{ IPDBNum = 568; NumPlayers = 1; Type = 'EM'; Theme = ''; Rating = 8.1 }
    "Corsario (Inder 1989)"                                                            = @{ IPDBNum = 4090; NumPlayers = 4; Type = 'SS'; Theme = 'Pirates'; Rating = 0 }
    "Corvette (Bally 1994)"                                                            = @{ IPDBNum = 570; NumPlayers = 4; Type = 'SS'; Theme = 'Cars'; Rating = 7.9 }
    "Cosmic (Taito do Brasil 1980)"                                                    = @{ IPDBNum = 4567; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Cosmic Gunfight (Williams 1982)"                                                  = @{ IPDBNum = 571; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.3 }
    "Cosmic Princess (Stern 1979)"                                                     = @{ IPDBNum = 3967; NumPlayers = 4; Type = 'SS'; Theme = 'Astrology'; Rating = 0 }
    "Cosmic Venus (Tilt Movie 1978)"                                                   = @{ IPDBNum = 5711; NumPlayers = 0; Type = 'EM'; Theme = 'Dinosaurs, Outer Space, Space Fantasy'; Rating = 0 }
    "Count-Down (Gottlieb 1979)"                                                       = @{ IPDBNum = 573; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Astronauts'; Rating = 7.5 }
    "Counterforce (Gottlieb 1980)"                                                     = @{ IPDBNum = 575; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 7.6 }
    "Cow Poke (Gottlieb 1965)"                                                         = @{ IPDBNum = 581; NumPlayers = 1; Type = 'EM'; Theme = 'American West'; Rating = 7.7 }
    "Cowboy Eight Ball (LTD do Brasil 1981)"                                           = @{ IPDBNum = 5132; NumPlayers = 3; Type = 'SS'; Theme = 'Billiards'; Rating = 0 }
    "Cowboy Eight Ball 2 (LTD do Brasil 1981)"                                         = @{ IPDBNum = 5734; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 0 }
    "Creature from the Black Lagoon - B&W Edition (Bally 1992)"                        = @{ IPDBNum = 588; NumPlayers = 4; Type = 'SS'; Theme = 'Drive-In, Movie, Fictional, Licensed Theme'; Rating = 8.2 }
    "Creature from the Black Lagoon - Nude Edition (Bally 1992)"                       = @{ IPDBNum = 588; NumPlayers = 4; Type = 'SS'; Theme = 'Drive-In, Movie, Fictional, Licensed Theme'; Rating = 8.2 }
    "Creature from the Black Lagoon (Bally 1992)"                                      = @{ IPDBNum = 588; NumPlayers = 4; Type = 'SS'; Theme = 'Drive-In, Movie, Fictional, Licensed Theme'; Rating = 8.2 }
    "Crescendo (Gottlieb 1970)"                                                        = @{ IPDBNum = 590; NumPlayers = 2; Type = 'EM'; Theme = 'Music, Singing, Dancing, Psychedelic'; Rating = 6.4 }
    "Criterium 75 (Recel 1975)"                                                        = @{ IPDBNum = 596; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Bicycle Racing'; Rating = 6.6 }
    "Cross Town (Gottlieb 1966)"                                                       = @{ IPDBNum = 601; NumPlayers = 1; Type = 'EM'; Theme = 'City Living'; Rating = 7.7 }
    "Crystal-Ball (Automaticos 1970)"                                                  = @{ IPDBNum = 5498; NumPlayers = 1; Type = 'EM'; Theme = 'Fortune Telling'; Rating = 0 }
    "CSI (Stern 2008)"                                                                 = @{ IPDBNum = 5348; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Detective, Crime, TV Show'; Rating = 6.7 }
    "Cue (Stern 1982)"                                                                 = @{ IPDBNum = 3873; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 0 }
    "Cue Ball Wizard (Gottlieb 1992)"                                                  = @{ IPDBNum = 610; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards, Celebrities, Fictional'; Rating = 7.3 }
    "Cybernaut (Bally 1985)"                                                           = @{ IPDBNum = 614; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 7 }
    "Cyclone (Williams 1988)"                                                          = @{ IPDBNum = 617; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Amusement Park, Roller Coasters'; Rating = 8 }
    "Cyclopes (Game Plan 1985)"                                                        = @{ IPDBNum = 619; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 0 }
    "Dale Jr. (Stern 2007)"                                                            = @{ IPDBNum = 5292; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing, Cars'; Rating = 7.2 }
    "Dark Rider (Geiger 1984)"                                                         = @{ IPDBNum = 3968; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Dark Shadow (Nuova Bell Games 1986)"                                              = @{ IPDBNum = 3699; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Darling (Williams 1973)"                                                          = @{ IPDBNum = 640; NumPlayers = 2; Type = 'EM'; Theme = 'Women'; Rating = 5.5 }
    "Deadly Weapon (Gottlieb 1990)"                                                    = @{ IPDBNum = 645; NumPlayers = 4; Type = 'SS'; Theme = 'Crime'; Rating = 7 }
    "Dealer's Choice (Williams 1973)"                                                  = @{ IPDBNum = 649; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.3 }
    "Defender (Williams 1982)"                                                         = @{ IPDBNum = 651; NumPlayers = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy, Video Game'; Rating = 7.4 }
    "Demolition Man - Limited Cryo Edition (Williams 1994)"                            = @{ IPDBNum = 662; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Licensed Theme, Movie, Action'; Rating = 8 }
    "Demolition Man (Williams 1994)"                                                   = @{ IPDBNum = 662; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Licensed Theme, Movie, Action'; Rating = 8 }
    "Dennis Lillee's Howzat! (Hankin 1980)"                                            = @{ IPDBNum = 3909; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Cricket'; Rating = 0 }
    "Devil Riders (Zaccaria 1984)"                                                     = @{ IPDBNum = 672; NumPlayers = 4; Type = 'SS'; Theme = 'Stunts, Motorcycles'; Rating = 7.4 }
    "Devil's Dare (Gottlieb 1982)"                                                     = @{ IPDBNum = 673; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.9 }
    "Diamond Jack (Gottlieb 1967)"                                                     = @{ IPDBNum = 676; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.7 }
    "Diamond Lady (Gottlieb 1988)"                                                     = @{ IPDBNum = 678; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 7.4 }
    "Dimension (Gottlieb 1971)"                                                        = @{ IPDBNum = 680; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 7.6 }
    "Diner (Williams 1990)"                                                            = @{ IPDBNum = 681; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Food'; Rating = 8 }
    "Dipsy Doodle (Williams 1970)"                                                     = @{ IPDBNum = 683; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Dancing'; Rating = 6.9 }
    "Dirty Harry (Williams 1995)"                                                      = @{ IPDBNum = 684; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional, Licensed Theme, Movie, Crime, Police'; Rating = 7.5 }
    "Disco (Stern 1977)"                                                               = @{ IPDBNum = 685; NumPlayers = 2; Type = 'EM'; Theme = 'Music, Singing, Dancing'; Rating = 0 }
    "Disco Dancing (LTD do Brasil 1979)"                                               = @{ IPDBNum = 5892; NumPlayers = 2; Type = 'SS'; Theme = 'Dancing, Happiness, Music, Nightlife'; Rating = 0 }
    "Disco Fever (Williams 1978)"                                                      = @{ IPDBNum = 686; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Dancing'; Rating = 5.9 }
    "Disney TRON Legacy (Limited Edition) - PuP-Pack Edition (Stern 2011)"             = @{ IPDBNum = 5682; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie'; Rating = 7.9 }
    "Disney TRON Legacy (Limited Edition) (Stern 2011)"                                = @{ IPDBNum = 5682; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie'; Rating = 7.9 }
    "Dixieland (Bally 1968)"                                                           = @{ IPDBNum = 692; NumPlayers = 1; Type = 'EM'; Theme = 'American Places, Happiness, Music'; Rating = 7.4 }
    "Doctor Who (Bally 1992)"                                                          = @{ IPDBNum = 738; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Science Fiction, Time Travel'; Rating = 7.9 }
    "Dogies (Bally 1968)"                                                              = @{ IPDBNum = 696; NumPlayers = 4; Type = 'EM'; Theme = 'American West'; Rating = 7.7 }
    "Dolly Parton (Bally 1979)"                                                        = @{ IPDBNum = 698; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music, Singing'; Rating = 6.8 }
    "Dolphin (Chicago Coin 1974)"                                                      = @{ IPDBNum = 699; NumPlayers = 2; Type = 'EM'; Theme = 'Aquatic Parks'; Rating = 0 }
    "Domino (Gottlieb 1968)"                                                           = @{ IPDBNum = 701; NumPlayers = 1; Type = 'EM'; Theme = 'Happiness, Games, Board Games'; Rating = 7.7 }
    "Domino (Gottlieb 1983)"                                                           = @{ IPDBNum = 5334; NumPlayers = 4; Type = 'SS'; Theme = 'Dominoes, Games'; Rating = 0 }
    "Doodle Bug (Williams 1971)"                                                       = @{ IPDBNum = 703; NumPlayers = 1; Type = 'EM'; Theme = 'Dancing, Happiness, Music'; Rating = 7.3 }
    "Double Barrel (Williams 1961)"                                                    = @{ IPDBNum = 709; NumPlayers = 2; Type = 'EM'; Theme = 'American West, Women'; Rating = 7.1 }
    "Double-Up (Bally 1970)"                                                           = @{ IPDBNum = 4447; NumPlayers = 1; Type = 'EM'; Theme = 'Motorcycles'; Rating = 0 }
    "Dr. Dude and His Excellent Ray (Bally 1990)"                                      = @{ IPDBNum = 737; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional'; Rating = 7.8 }
    "Dracula (Stern 1979)"                                                             = @{ IPDBNum = 728; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional, Supernatural, Horror'; Rating = 7 }
    "Dragon (Gottlieb 1978)"                                                           = @{ IPDBNum = 4697; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 0 }
    "Dragon (Interflip 1977)"                                                          = @{ IPDBNum = 3887; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy, Dragons'; Rating = 7.4 }
    "Dragon (SS) (Gottlieb 1978)"                                                      = @{ IPDBNum = 729; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Dragons'; Rating = 6 }
    "Dragonette (Gottlieb 1954)"                                                       = @{ IPDBNum = 730; NumPlayers = 0; Type = 'EM'; Theme = 'Detective, Crime'; Rating = 0 }
    "Dragonfist (Stern 1981)"                                                          = @{ IPDBNum = 731; NumPlayers = 4; Type = 'SS'; Theme = 'Martial Arts, Sports'; Rating = 0 }
    "Dragoon (Recreativos Franco 1977)"                                                = @{ IPDBNum = 4872; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy, Dragons'; Rating = 0 }
    "Drakor (Taito do Brasil 1979)"                                                    = @{ IPDBNum = 4569; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Drop-A-Card (Gottlieb 1971)"                                                      = @{ IPDBNum = 735; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.7 }
    "Dungeons & Dragons (Bally 1987)"                                                  = @{ IPDBNum = 743; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Fantasy, Dragons, Roleplaying'; Rating = 7 }
    "Duotron (Gottlieb 1974)"                                                          = @{ IPDBNum = 744; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy'; Rating = 6.6 }
    "Dutch Pool (A.B.T. 1931)"                                                         = @{ IPDBNum = 747; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Eager Beaver (Williams 1965)"                                                     = @{ IPDBNum = 752; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy'; Rating = 0 }
    "Earth Wind Fire (Zaccaria 1981)"                                                  = @{ IPDBNum = 3611; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Earthshaker (Williams 1989)"                                                      = @{ IPDBNum = 753; NumPlayers = 4; Type = 'SS'; Theme = 'Earthquake'; Rating = 7.9 }
    "Eclipse (Gottlieb 1982)"                                                          = @{ IPDBNum = 756; NumPlayers = 4; Type = 'SS'; Theme = 'Mysticism'; Rating = 0 }
    "Egg Head (Gottlieb 1961)"                                                         = @{ IPDBNum = 758; NumPlayers = 1; Type = 'EM'; Theme = 'Games, Board Games, Tic-Tac-Toe'; Rating = 7.1 }
    "Eight Ball (Bally 1977)"                                                          = @{ IPDBNum = 760; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 7.3 }
    "Eight Ball Champ (Bally 1985)"                                                    = @{ IPDBNum = 761; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 7.5 }
    "El Dorado (Gottlieb 1975)"                                                        = @{ IPDBNum = 766; NumPlayers = 1; Type = 'EM'; Theme = 'American West'; Rating = 7.8 }
    "El Dorado City of Gold (Gottlieb 1984)"                                           = @{ IPDBNum = 767; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Fantasy'; Rating = 6.9 }
    "Electra-Pool (Gottlieb 1965)"                                                     = @{ IPDBNum = 779; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 0 }
    "Elektra (Bally 1981)"                                                             = @{ IPDBNum = 778; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "Elite Guard (Gottlieb 1968)"                                                      = @{ IPDBNum = 780; NumPlayers = 1; Type = 'EM'; Theme = 'World Places, Historical'; Rating = 0 }
    "Elvira and the Party Monsters - Nude Edition (Bally 1989)"                        = @{ IPDBNum = 782; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Horror, Supernatural'; Rating = 7.9 }
    "Elvira and the Party Monsters (Bally 1989)"                                       = @{ IPDBNum = 782; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Horror, Supernatural'; Rating = 7.9 }
    "Elvis (Stern 2004)"                                                               = @{ IPDBNum = 4983; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Rock, Pop, Country and Western, Blues, Soul'; Rating = 7.6 }
    "Elvis Gold (Limited Edition) (Stern 2004)"                                        = @{ IPDBNum = 6032; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 0 }
    "Embryon (Bally 1981)"                                                             = @{ IPDBNum = 783; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Science Fiction'; Rating = 7.9 }
    "Escape from the Lost World (Bally 1988)"                                          = @{ IPDBNum = 789; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Dinosaurs'; Rating = 7.5 }
    "Evel Knievel (Bally 1977)"                                                        = @{ IPDBNum = 4499; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Stunts'; Rating = 7.5 }
    "Evil Fight (Playmatic 1980)"                                                      = @{ IPDBNum = 3085; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Excalibur (Gottlieb 1988)"                                                        = @{ IPDBNum = 795; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Knights, Mythology'; Rating = 0 }
    "Eye Of The Tiger (Gottlieb 1978)"                                                 = @{ IPDBNum = 802; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy, Myth and Legend'; Rating = 7.8 }
    "F-14 Tomcat (Williams 1987)"                                                      = @{ IPDBNum = 804; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Combat, Aviation'; Rating = 7.7 }
    "Faces (Sonic 1976)"                                                               = @{ IPDBNum = 806; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy, Psychedelic'; Rating = 7.2 }
    "Faeton (Juegos Populares 1985)"                                                   = @{ IPDBNum = 3087; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy'; Rating = 0 }
    "Fair Fight (Recel 1978)"                                                          = @{ IPDBNum = 808; NumPlayers = 4; Type = 'SS'; Theme = 'Medieval, Combat'; Rating = 0 }
    "Family Guy (Stern 2007)"                                                          = @{ IPDBNum = 5219; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Animation, TV Show'; Rating = 7.8 }
    "Fan-Tas-Tic (Williams 1972)"                                                      = @{ IPDBNum = 820; NumPlayers = 4; Type = 'EM'; Theme = 'Dancing, Happiness, Music'; Rating = 7.7 }
    "Far Out (Gottlieb 1974)"                                                          = @{ IPDBNum = 823; NumPlayers = 4; Type = 'EM'; Theme = 'Psychedelic'; Rating = 7.3 }
    "Farfalla (Zaccaria 1983)"                                                         = @{ IPDBNum = 824; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 7.9 }
    "Farwest (Fliperbol 1980)"                                                         = @{ IPDBNum = 4593; NumPlayers = 4; Type = 'SS'; Theme = 'American West'; Rating = 0 }
    "Fashion Show (Gottlieb 1962)"                                                     = @{ IPDBNum = 825; NumPlayers = 2; Type = 'EM'; Theme = 'Fashion Show, Pageantry, Women'; Rating = 7.3 }
    "Fast Draw (Gottlieb 1975)"                                                        = @{ IPDBNum = 828; NumPlayers = 4; Type = 'EM'; Theme = 'American West'; Rating = 7.8 }
    "Fathom - LED Edition (Bally 1981)"                                                = @{ IPDBNum = 829; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Scuba Diving, Sports, Aquatic'; Rating = 7.9 }
    "Fathom (Bally 1981)"                                                              = @{ IPDBNum = 829; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Scuba Diving, Sports, Aquatic'; Rating = 7.9 }
    "Fifteen (Inder 1974)"                                                             = @{ IPDBNum = 4409; NumPlayers = 1; Type = 'EM'; Theme = 'Women'; Rating = 0 }
    "Fire Action (Taito do Brasil 1980)"                                               = @{ IPDBNum = 4570; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Fire Action De Luxe (Taito do Brasil 1983)"                                       = @{ IPDBNum = 4552; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Fire Queen (Gottlieb 1977)"                                                       = @{ IPDBNum = 851; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.7 }
    "Fire! (Williams 1987)"                                                            = @{ IPDBNum = 859; NumPlayers = 4; Type = 'SS'; Theme = 'Fire Fighting'; Rating = 7.5 }
    "Fireball (Bally 1972)"                                                            = @{ IPDBNum = 852; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.8 }
    "Fireball Classic (Bally 1985)"                                                    = @{ IPDBNum = 853; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "Fireball II (Bally 1981)"                                                         = @{ IPDBNum = 854; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.8 }
    "Firecracker (Bally 1971)"                                                         = @{ IPDBNum = 855; NumPlayers = 4; Type = 'EM'; Theme = 'Celebration, Festivities'; Rating = 7.4 }
    "Firepower (Williams 1980)"                                                        = @{ IPDBNum = 856; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.8 }
    "Firepower II (Williams 1983)"                                                     = @{ IPDBNum = 857; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.4 }
    "Firepower vs. A.I. (Williams 1980)"                                               = @{ IPDBNum = 856; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.8 }
    "Fish Tales (Williams 1992)"                                                       = @{ IPDBNum = 861; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Fishing'; Rating = 8.1 }
    "FJ (Hankin 1978)"                                                                 = @{ IPDBNum = 3627; NumPlayers = 4; Type = 'SS'; Theme = 'Cars'; Rating = 0 }
    "Flash (Williams 1979)"                                                            = @{ IPDBNum = 871; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.7 }
    "Flash Dragon (Playmatic 1986)"                                                    = @{ IPDBNum = 3616; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Flash Gordon (Bally 1981)"                                                        = @{ IPDBNum = 874; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional Characters'; Rating = 8 }
    "Flash, The (Original 2018)"                                                       = @{ IPDBNum = 871; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Superheroes'; Rating = 7.7 }
    "Flashman (Sport matic 1984)"                                                      = @{ IPDBNum = 5218; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Fleet Jr. (Bally 1934)"                                                           = @{ IPDBNum = 880; NumPlayers = 1; Type = 'EM'; Theme = 'Flipperless'; Rating = 0 }
    "Flicker (Bally 1975)"                                                             = @{ IPDBNum = 883; NumPlayers = 2; Type = 'EM'; Theme = 'Show Business, Celebrities'; Rating = 5.8 }
    "Flight 2000 (Stern 1980)"                                                         = @{ IPDBNum = 887; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.5 }
    "Flintstones, The - Cartoon Edition (Williams 1994)"                               = @{ IPDBNum = 888; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie'; Rating = 7.9 }
    "Flintstones, The - The Cartoon VR Edition (Williams 1994)"                        = @{ IPDBNum = 888; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie'; Rating = 7.9 }
    "Flintstones, The - VR Cartoon Edition (Williams 1994)"                            = @{ IPDBNum = 888; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie'; Rating = 7.9 }
    "Flintstones, The - Yabba Dabba Re-Doo Edition (Williams 1994)"                    = @{ IPDBNum = 888; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie'; Rating = 7.9 }
    "Flintstones, The (Williams 1994)"                                                 = @{ IPDBNum = 888; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie'; Rating = 7.9 }
    "Flip a Card (Gottlieb 1970)"                                                      = @{ IPDBNum = 890; NumPlayers = 1; Type = 'EM'; Theme = 'College Life, Happiness, Music, Cards'; Rating = 7.7 }
    "Flip Flop (Bally 1976)"                                                           = @{ IPDBNum = 889; NumPlayers = 4; Type = 'EM'; Theme = 'American West, Rodeo'; Rating = 6.8 }
    "Flipper Fair (Gottlieb 1961)"                                                     = @{ IPDBNum = 894; NumPlayers = 1; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 7.6 }
    "Flipper Football (Capcom 1996)"                                                   = @{ IPDBNum = 3945; NumPlayers = 6; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 7 }
    "Flipper Pool (Gottlieb 1965)"                                                     = @{ IPDBNum = 896; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 8.3 }
    "Flying Carpet (Gottlieb 1972)"                                                    = @{ IPDBNum = 899; NumPlayers = 1; Type = 'EM'; Theme = 'Fantasy, Mythology'; Rating = 7.7 }
    "Flying Chariots (Gottlieb 1963)"                                                  = @{ IPDBNum = 901; NumPlayers = 2; Type = 'EM'; Theme = 'Historical'; Rating = 6.7 }
    "Flying Turns (Midway 1964)"                                                       = @{ IPDBNum = 910; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Auto Racing'; Rating = 7.7 }
    "Football (Taito do Brasil 1979)"                                                  = @{ IPDBNum = 5199; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 0 }
    "Force (LTD do Brasil 1979)"                                                       = @{ IPDBNum = 5893; NumPlayers = 2; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy'; Rating = 0 }
    "Force II (Gottlieb 1981)"                                                         = @{ IPDBNum = 916; NumPlayers = 4; Type = 'SS'; Theme = 'Combat, Aliens, Outer Space'; Rating = 6.8 }
    "Four Million B.C. (Bally 1971)"                                                   = @{ IPDBNum = 935; NumPlayers = 4; Type = 'EM'; Theme = 'Dinosaurs, Historical'; Rating = 7.6 }
    "Four Seasons (Gottlieb 1968)"                                                     = @{ IPDBNum = 939; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Recreation, Water Skiing, Ice Skating, Hunting'; Rating = 6.9 }
    "Frank Thomas' Big Hurt (Gottlieb 1995)"                                           = @{ IPDBNum = 3591; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Baseball'; Rating = 7.7 }
    "Freddy - A Nightmare on Elm Street (Gottlieb 1994)"                               = @{ IPDBNum = 948; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Horror, Movie'; Rating = 7.5 }
    "Free Fall (Gottlieb 1974)"                                                        = @{ IPDBNum = 949; NumPlayers = 1; Type = 'EM'; Theme = 'Parachuting, Sports, Skydiving'; Rating = 7.5 }
    "Freedom (EM) (Bally 1976)"                                                        = @{ IPDBNum = 952; NumPlayers = 4; Type = 'EM'; Theme = 'American History, Celebration'; Rating = 7.7 }
    "Freedom (SS) (Bally 1976)"                                                        = @{ IPDBNum = 4500; NumPlayers = 4; Type = 'SS'; Theme = 'American History, Celebration'; Rating = 0 }
    "Freefall (Stern 1981)"                                                            = @{ IPDBNum = 953; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 6.5 }
    "Frontier (Bally 1980)"                                                            = @{ IPDBNum = 959; NumPlayers = 4; Type = 'SS'; Theme = 'American West'; Rating = 7.4 }
    "Full (Recreativos Franco 1977)"                                                   = @{ IPDBNum = 4707; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.7 }
    "Full House (Williams 1966)"                                                       = @{ IPDBNum = 961; NumPlayers = 1; Type = 'EM'; Theme = 'American West, Cards, Gambling'; Rating = 7.5 }
    "Full Throttle (Original 2023)"                                                    = @{ IPDBNum = 6301; NumPlayers = 0; Type = 'SS'; Theme = 'Sports, Motorcycle Racing'; Rating = 8.2 }
    "Fun Fair (Gottlieb 1968)"                                                         = @{ IPDBNum = 964; NumPlayers = 1; Type = 'EM'; Theme = 'Carnival, Shooting Gallery'; Rating = 0 }
    "Fun Land (Gottlieb 1968)"                                                         = @{ IPDBNum = 973; NumPlayers = 1; Type = 'EM'; Theme = 'Amusement Park'; Rating = 7.6 }
    "Fun Park (Gottlieb 1968)"                                                         = @{ IPDBNum = 968; NumPlayers = 1; Type = 'EM'; Theme = 'Carnival, Shooting Gallery'; Rating = 8.2 }
    "Fun-Fest (Williams 1972)"                                                         = @{ IPDBNum = 972; NumPlayers = 4; Type = 'EM'; Theme = 'Music, Dancing, People, Singing'; Rating = 7.2 }
    "Funhouse (Williams 1990)"                                                         = @{ IPDBNum = 966; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival'; Rating = 8.1 }
    "Future Spa (Bally 1979)"                                                          = @{ IPDBNum = 974; NumPlayers = 4; Type = 'SS'; Theme = 'Fitness, Fantasy, Relaxation'; Rating = 7.5 }
    "Galaxie (Gottlieb 1971)"                                                          = @{ IPDBNum = 978; NumPlayers = 1; Type = 'EM'; Theme = 'Science Fiction, Outer Space'; Rating = 0 }
    "Galaxy (Sega 1973)"                                                               = @{ IPDBNum = 979; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Science Fiction, Space Fantasy'; Rating = 0 }
    "Galaxy (Stern 1980)"                                                              = @{ IPDBNum = 980; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.4 }
    "Galaxy Play (CIC Play 1986)"                                                      = @{ IPDBNum = 4631; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Gamatron (Pinstar 1985)"                                                          = @{ IPDBNum = 984; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Gamatron (Sonic 1986)"                                                            = @{ IPDBNum = 3116; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction'; Rating = 0 }
    "Game of Thrones (Limited Edition) (Stern 2015)"                                   = @{ IPDBNum = 6309; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Medieval, Fantasy, Dragons'; Rating = 8.7 }
    "Games I, The (Gottlieb 1983)"                                                     = @{ IPDBNum = 5340; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Olympic Competition'; Rating = 0 }
    "Games, The (Gottlieb 1984)"                                                       = @{ IPDBNum = 3391; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Olympic Games'; Rating = 0 }
    "Gaucho (Gottlieb 1963)"                                                           = @{ IPDBNum = 988; NumPlayers = 4; Type = 'EM'; Theme = 'Adventure, World Culture'; Rating = 7 }
    "Gay 90's (Williams 1970)"                                                         = @{ IPDBNum = 989; NumPlayers = 4; Type = 'EM'; Theme = 'American History, Historical'; Rating = 7.7 }
    "Gemini (Gottlieb 1978)"                                                           = @{ IPDBNum = 995; NumPlayers = 2; Type = 'EM'; Theme = 'Astrology, Fantasy'; Rating = 0 }
    "Gemini 2000 (Taito do Brasil 1982)"                                               = @{ IPDBNum = 4579; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Genesis (Gottlieb 1986)"                                                          = @{ IPDBNum = 996; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "Genie - Fuzzel Physics Edition (Gottlieb 1979)"                                   = @{ IPDBNum = 997; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.3 }
    "Genie (Gottlieb 1979)"                                                            = @{ IPDBNum = 997; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.3 }
    "Getaway - High Speed II, The (Williams 1992)"                                     = @{ IPDBNum = 1000; NumPlayers = 4; Type = 'SS'; Theme = 'Police, Speeding, Cars'; Rating = 8 }
    "Ghostbusters (Limited Edition) (Stern 2016)"                                      = @{ IPDBNum = 6334; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Supernatural, Movie'; Rating = 8.9 }
    "Gigi (Gottlieb 1963)"                                                             = @{ IPDBNum = 1003; NumPlayers = 1; Type = 'EM'; Theme = 'Circus, Carnival'; Rating = 7.7 }
    "Gilligan's Island (Bally 1991)"                                                   = @{ IPDBNum = 1004; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme'; Rating = 7.1 }
    "Gladiators (Gottlieb 1993)"                                                       = @{ IPDBNum = 1011; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 7.3 }
    "Godzilla (Sega 1998)"                                                             = @{ IPDBNum = 4443; NumPlayers = 6; Type = 'SS'; Theme = 'Licensed Theme, Fantasy, Monsters'; Rating = 7.1 }
    "Goin' Nuts (Gottlieb 1983)"                                                       = @{ IPDBNum = 1021; NumPlayers = 4; Type = 'SS'; Theme = 'Wildlife'; Rating = 0 }
    "Gold Ball (Bally 1983)"                                                           = @{ IPDBNum = 1024; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 6.9 }
    "Gold Crown (Pierce 1932)"                                                         = @{ IPDBNum = 1026; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Gold Rush (Williams 1971)"                                                        = @{ IPDBNum = 1036; NumPlayers = 4; Type = 'EM'; Theme = 'Canadian West, Prospecting'; Rating = 7 }
    "Gold Star (Gottlieb 1954)"                                                        = @{ IPDBNum = 1038; NumPlayers = 1; Type = 'EM'; Theme = ''; Rating = 0 }
    "Gold Strike (Gottlieb 1975)"                                                      = @{ IPDBNum = 1042; NumPlayers = 1; Type = 'EM'; Theme = 'American West, Prospecting'; Rating = 7.8 }
    "Gold Wings (Gottlieb 1986)"                                                       = @{ IPDBNum = 1043; NumPlayers = 4; Type = 'SS'; Theme = 'Aviation, Combat'; Rating = 6.9 }
    "Golden Arrow (Gottlieb 1977)"                                                     = @{ IPDBNum = 1044; NumPlayers = 1; Type = 'EM'; Theme = 'American West, Native Americans, Warriors'; Rating = 7.6 }
    "Golden Cue (Sega 1998)"                                                           = @{ IPDBNum = 4383; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 0 }
    "Goldeneye (Sega 1996)"                                                            = @{ IPDBNum = 3792; NumPlayers = 6; Type = 'SS'; Theme = 'Licensed Theme, Movie, Espionage'; Rating = 7.7 }
    "Gorgar (Williams 1979)"                                                           = @{ IPDBNum = 1062; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.5 }
    "Gork (Taito do Brasil 1982)"                                                      = @{ IPDBNum = 4590; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Grand Casino (J.P. Seeburg 1934)"                                                 = @{ IPDBNum = 4194; NumPlayers = 1; Type = 'EM'; Theme = 'Flipperless'; Rating = 0 }
    "Grand Lizard (Williams 1986)"                                                     = @{ IPDBNum = 1070; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.5 }
    "Grand Prix (Stern 2005)"                                                          = @{ IPDBNum = 5120; NumPlayers = 0; Type = 'SS'; Theme = ''; Rating = 7.8 }
    "Grand Prix (Williams 1976)"                                                       = @{ IPDBNum = 1072; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Auto Racing'; Rating = 7.5 }
    "Grand Slam (Bally 1983)"                                                          = @{ IPDBNum = 1079; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Baseball'; Rating = 0 }
    "Grand Slam (Gottlieb 1972)"                                                       = @{ IPDBNum = 1078; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.7 }
    "Grand Tour (Bally 1964)"                                                          = @{ IPDBNum = 1081; NumPlayers = 1; Type = 'EM'; Theme = 'Travel, World Places'; Rating = 7.1 }
    "Grande Domino (Gottlieb 1968)"                                                    = @{ IPDBNum = 1069; NumPlayers = 1; Type = 'EM'; Theme = 'Dominoes, Games, Board Games'; Rating = 0 }
    "Granny and the Gators (Bally 1984)"                                               = @{ IPDBNum = 1083; NumPlayers = 2; Type = 'SS'; Theme = 'Hunting, Aquatic'; Rating = 0 }
    "Gridiron (Gottlieb 1977)"                                                         = @{ IPDBNum = 1089; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, American Football'; Rating = 8.5 }
    "Groovy (Gottlieb 1970)"                                                           = @{ IPDBNum = 1091; NumPlayers = 4; Type = 'EM'; Theme = 'Psychedelic, Flower Power'; Rating = 0 }
    "Guardians of the Galaxy (Pro) (Stern 2017)"                                       = @{ IPDBNum = 6474; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes, Movie'; Rating = 0 }
    "Gulfstream (Williams 1973)"                                                       = @{ IPDBNum = 1094; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Aquatic'; Rating = 7.6 }
    "Gun Men (Staal 1979)"                                                             = @{ IPDBNum = 3131; NumPlayers = 4; Type = 'SS'; Theme = 'Western'; Rating = 0 }
    "Guns N' Roses (Data East 1994)"                                                   = @{ IPDBNum = 1100; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music'; Rating = 8 }
    "Hairy-Singers (Rally 1966)"                                                       = @{ IPDBNum = 3133; NumPlayers = 1; Type = 'EM'; Theme = 'Singing, Prehistoric'; Rating = 0 }
    "Halley Comet - Alternate Plastics Edition (Juegos Populares 1986)"                = @{ IPDBNum = 3936; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Halley Comet (Juegos Populares 1986)"                                             = @{ IPDBNum = 3936; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Hang Glider (Bally 1976)"                                                         = @{ IPDBNum = 1112; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Hang Gliding'; Rating = 7.7 }
    "Hardbody (Bally 1987)"                                                            = @{ IPDBNum = 1122; NumPlayers = 4; Type = 'SS'; Theme = 'Exercise, Body Building'; Rating = 6.6 }
    "Harlem Globetrotters on Tour (Bally 1979)"                                        = @{ IPDBNum = 1125; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball, Licensed Theme'; Rating = 7.5 }
    "Harley-Davidson (Bally 1991)"                                                     = @{ IPDBNum = 1126; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Motorcycles'; Rating = 6.3 }
    "Harley-Davidson (Sega 1999)"                                                      = @{ IPDBNum = 4453; NumPlayers = 6; Type = 'SS'; Theme = 'Licensed Theme, Motorcycles'; Rating = 6.7 }
    "Harmony (Gottlieb 1967)"                                                          = @{ IPDBNum = 1127; NumPlayers = 1; Type = 'EM'; Theme = 'Happiness, Singing'; Rating = 0 }
    "Haunted Hotel (LTD do Brasil 1983)"                                               = @{ IPDBNum = 5704; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Supernatural'; Rating = 0 }
    "Haunted House (Gottlieb 1982)"                                                    = @{ IPDBNum = 1133; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Supernatural'; Rating = 7.7 }
    "Hawkman (Taito do Brasil 1983)"                                                   = @{ IPDBNum = 4512; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 0 }
    "Hayburners (Williams 1951)"                                                       = @{ IPDBNum = 1142; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 0 }
    "Hearts and Spades (Gottlieb 1969)"                                                = @{ IPDBNum = 1145; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.6 }
    "Hearts Gain (Inder 1971)"                                                         = @{ IPDBNum = 4406; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Cards'; Rating = 0 }
    "Heat Wave (Williams 1964)"                                                        = @{ IPDBNum = 1148; NumPlayers = 1; Type = 'EM'; Theme = 'Beach, Swimming'; Rating = 7.8 }
    "Heavy Metal (Rowamet 1981)"                                                       = @{ IPDBNum = 5175; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Heavy Metal Meltdown (Bally 1987)"                                                = @{ IPDBNum = 1150; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Heavy Metal'; Rating = 7.1 }
    "Hercules (Atari 1979)"                                                            = @{ IPDBNum = 1155; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 5.1 }
    "Hi-Deal (Bally 1975)"                                                             = @{ IPDBNum = 1157; NumPlayers = 1; Type = 'EM'; Theme = 'Aircraft, Aviation, City Buildings, City Scene, Cards'; Rating = 7.4 }
    "Hi-Diver (Gottlieb 1959)"                                                         = @{ IPDBNum = 1165; NumPlayers = 1; Type = 'EM'; Theme = 'Aquatic, Diving'; Rating = 7.3 }
    "Hi-Lo (Gottlieb 1969)"                                                            = @{ IPDBNum = 1184; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Hi-Lo Ace (Bally 1973)"                                                           = @{ IPDBNum = 1187; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.6 }
    "Hi-Score (Gottlieb 1967)"                                                         = @{ IPDBNum = 1160; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Pinball'; Rating = 7.3 }
    "Hi-Score Pool (Chicago Coin 1971)"                                                = @{ IPDBNum = 1161; NumPlayers = 2; Type = 'EM'; Theme = 'Billiards'; Rating = 5.6 }
    "Hi-Skor (Hi-Skor 1932)"                                                           = @{ IPDBNum = 5225; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "High Hand (Gottlieb 1973)"                                                        = @{ IPDBNum = 1173; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.5 }
    "High Roller Casino (Stern 2001)"                                                  = @{ IPDBNum = 4502; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 7.1 }
    "High Seas (Gottlieb 1976)"                                                        = @{ IPDBNum = 1175; NumPlayers = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical'; Rating = 0 }
    "High Speed (Williams 1986)"                                                       = @{ IPDBNum = 1176; NumPlayers = 4; Type = 'SS'; Theme = 'Cars, Police, Speeding'; Rating = 8 }
    "Hit the Deck (Gottlieb 1978)"                                                     = @{ IPDBNum = 1201; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Aquatic, Mythology'; Rating = 8.1 }
    "Hokus Pokus (Bally 1976)"                                                         = @{ IPDBNum = 1206; NumPlayers = 2; Type = 'EM'; Theme = 'Magic, Show Business'; Rating = 7.5 }
    "Hollywood Heat (Gottlieb 1986)"                                                   = @{ IPDBNum = 1219; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional'; Rating = 7 }
    "Home Run (Gottlieb 1971)"                                                         = @{ IPDBNum = 1224; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.4 }
    "Honey (Williams 1971)"                                                            = @{ IPDBNum = 1230; NumPlayers = 4; Type = 'EM'; Theme = 'Women, Romance'; Rating = 7.3 }
    "Hook (Data East 1992)"                                                            = @{ IPDBNum = 1233; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Pirates, Fictional, Movie'; Rating = 7.5 }
    "Hoops (Gottlieb 1991)"                                                            = @{ IPDBNum = 1235; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball'; Rating = 7.3 }
    "Hootenanny (Bally 1963)"                                                          = @{ IPDBNum = 1236; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing, Dancing'; Rating = 0 }
    "Horseshoe (A.B.T. 1931)"                                                          = @{ IPDBNum = 3158; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless, Games'; Rating = 0 }
    "Hot Ball (Taito do Brasil 1979)"                                                  = @{ IPDBNum = 4665; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Billiards'; Rating = 0 }
    "Hot Hand (Stern 1979)"                                                            = @{ IPDBNum = 1244; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 7.2 }
    "Hot Line (Williams 1966)"                                                         = @{ IPDBNum = 1245; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Fishing'; Rating = 7.7 }
    "Hot Shot (Gottlieb 1973)"                                                         = @{ IPDBNum = 1247; NumPlayers = 4; Type = 'EM'; Theme = 'Billiards'; Rating = 7.2 }
    "Hot Shots (Gottlieb 1989)"                                                        = @{ IPDBNum = 1248; NumPlayers = 4; Type = 'SS'; Theme = 'Circus, Carnival'; Rating = 6.7 }
    "Hot Tip - Less Reflections Edition (Williams 1977)"                               = @{ IPDBNum = 3163; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Horse Racing'; Rating = 7.5 }
    "Hot Tip (Williams 1977)"                                                          = @{ IPDBNum = 3163; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Horse Racing'; Rating = 7.5 }
    "Hotdoggin' (Bally 1980)"                                                          = @{ IPDBNum = 1243; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Skiing'; Rating = 7.8 }
    "House of Diamonds (Zaccaria 1978)"                                                = @{ IPDBNum = 3165; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Humpty Dumpty (Gottlieb 1947)"                                                    = @{ IPDBNum = 1254; NumPlayers = 1; Type = 'EM'; Theme = 'Fictional Characters, Flipperless'; Rating = 7.2 }
    "Hunter (Jennings 1935)"                                                           = @{ IPDBNum = 1255; NumPlayers = 1; Type = 'PM'; Theme = 'Sports, Hunting, Flipperless'; Rating = 0 }
    "Hurricane (Williams 1991)"                                                        = @{ IPDBNum = 1257; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival, Roller Coasters, Amusement Park'; Rating = 7.5 }
    "Hustler (LTD do Brasil 1980)"                                                     = @{ IPDBNum = 6706; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Billiards'; Rating = 0 }
    "Hyperball - Analog Joystick Edition (Williams 1981)"                              = @{ IPDBNum = 3169; NumPlayers = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 6.9 }
    "Hyperball - Analog Mouse Edition (Williams 1981)"                                 = @{ IPDBNum = 3169; NumPlayers = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 6.9 }
    "Hyperball (Williams 1981)"                                                        = @{ IPDBNum = 3169; NumPlayers = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 6.9 }
    "Ice Cold Beer (Taito 1983)"                                                       = @{ IPDBNum = 6802; NumPlayers = 2; Type = 'EM'; Theme = 'Drinking, Flipperless, Beer'; Rating = 0 }
    "Ice Fever (Gottlieb 1985)"                                                        = @{ IPDBNum = 1260; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Hockey'; Rating = 6.9 }
    "Impacto (Recreativos Franco 1975)"                                                = @{ IPDBNum = 4868; NumPlayers = 1; Type = 'EM'; Theme = 'Circus'; Rating = 7.5 }
    "Incredible Hulk, The (Gottlieb 1979)"                                             = @{ IPDBNum = 1266; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes'; Rating = 7.3 }
    "Independence Day (Sega 1996)"                                                     = @{ IPDBNum = 3878; NumPlayers = 6; Type = 'SS'; Theme = 'Outer Space, Licensed Theme, Movie'; Rating = 7.5 }
    "Indiana Jones - The Pinball Adventure (Williams 1993)"                            = @{ IPDBNum = 1267; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Fictional, Licensed Theme, Movie'; Rating = 8.3 }
    "Indiana Jones (Stern 2008)"                                                       = @{ IPDBNum = 5306; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Mythology, Movie, Adventure'; Rating = 7.1 }
    "Indianapolis 500 (Bally 1995)"                                                    = @{ IPDBNum = 2853; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 7.9 }
    "Iron Balls (Unidesa 1987)"                                                        = @{ IPDBNum = 4426; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 0 }
    "Iron Maiden (Stern 1982)"                                                         = @{ IPDBNum = 1270; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Music, Rock n roll'; Rating = 6.6 }
    "Iron Man (Pro Vault Edition) (Stern 2014)"                                        = @{ IPDBNum = 6154; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Movie, Superheroes'; Rating = 0 }
    "Iron Man (Stern 2010)"                                                            = @{ IPDBNum = 5550; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Fantasy, Superheroes, Movie'; Rating = 7.8 }
    "Jack in the Box (Gottlieb 1973)"                                                  = @{ IPDBNum = 1277; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 7.6 }
    "Jack-Bot (Williams 1995)"                                                         = @{ IPDBNum = 3619; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Gambling'; Rating = 7.6 }
    "Jackpot (Williams 1971)"                                                          = @{ IPDBNum = 1279; NumPlayers = 4; Type = 'EM'; Theme = 'Canadian West, Prospecting'; Rating = 7.7 }
    "Jacks Open (Gottlieb 1977)"                                                       = @{ IPDBNum = 1281; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "Jacks to Open (Gottlieb 1984)"                                                    = @{ IPDBNum = 1282; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling, Cards, Poker'; Rating = 7 }
    "Jake Mate (Recel 1974)"                                                           = @{ IPDBNum = 1283; NumPlayers = 1; Type = 'EM'; Theme = 'Chess'; Rating = 0 }
    "Jalisco (Recreativos Franco 1976)"                                                = @{ IPDBNum = 4667; NumPlayers = 1; Type = 'EM'; Theme = 'Mexico'; Rating = 0 }
    "Jalopy (Williams 1951)"                                                           = @{ IPDBNum = 1284; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Auto Racing'; Rating = 0 }
    "James Bond 007 (Gottlieb 1980)"                                                   = @{ IPDBNum = 1286; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Espionage'; Rating = 6 }
    "James Cameron's Avatar (Stern 2010)"                                              = @{ IPDBNum = 5618; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Science Fiction'; Rating = 7.3 }
    "Jet Spin (Gottlieb 1977)"                                                         = @{ IPDBNum = 1290; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy, Recreation'; Rating = 7.8 }
    "Jive Time (Williams 1970)"                                                        = @{ IPDBNum = 1298; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing'; Rating = 6.5 }
    "Johnny Mnemonic (Williams 1995)"                                                  = @{ IPDBNum = 3683; NumPlayers = 4; Type = 'SS'; Theme = 'Movie, Fictional, Licensed Theme'; Rating = 7.8 }
    "Joker (Gottlieb 1950)"                                                            = @{ IPDBNum = 1304; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Cards, Poker'; Rating = 0 }
    "Joker Poker (EM) (Gottlieb 1978)"                                                 = @{ IPDBNum = 5078; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "Joker Poker (SS) (Gottlieb 1978)"                                                 = @{ IPDBNum = 1306; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 8 }
    "Joker Wild (Bally 1970)"                                                          = @{ IPDBNum = 3573; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Jokerz! (Williams 1988)"                                                          = @{ IPDBNum = 1308; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 7.6 }
    "Jolly Park (Spinball S.A.L. 1996)"                                                = @{ IPDBNum = 4618; NumPlayers = 4; Type = 'SS'; Theme = 'Amusement Park, Roller Coasters'; Rating = 7.5 }
    "Jolly Roger (Williams 1967)"                                                      = @{ IPDBNum = 1314; NumPlayers = 4; Type = 'EM'; Theme = 'Historical, Pirates'; Rating = 7.4 }
    "Joust (Bally 1969)"                                                               = @{ IPDBNum = 1317; NumPlayers = 2; Type = 'EM'; Theme = 'Medieval, Knights'; Rating = 7.3 }
    "Joust (Williams 1983)"                                                            = @{ IPDBNum = 1316; NumPlayers = 2; Type = 'SS'; Theme = 'Video Game'; Rating = 0 }
    "JP's Addams Family (Bally 1992)"                                                  = @{ IPDBNum = 20; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie'; Rating = 8.3 }
    "JP's Captain Fantastic (Bally 1976)"                                              = @{ IPDBNum = 438; NumPlayers = 4; Type = 'EM'; Theme = 'Celebrities, Fictional, Licensed Theme'; Rating = 7.7 }
    "JP's Cyclone (Original 2022)"                                                     = @{ IPDBNum = 617; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Amusement Park, Roller Coasters'; Rating = 8 }
    "JP's Grand Prix (Stern 2005)"                                                     = @{ IPDBNum = 5120; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 7.8 }
    "JP's Indiana Jones (Stern 2008)"                                                  = @{ IPDBNum = 5306; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Mythology'; Rating = 7.1 }
    "JP's Iron Man 2 - Armored Adventures (Original 2018)"                             = @{ IPDBNum = 6154; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes'; Rating = 0 }
    "JP's Mephisto (Cirsa 1987)"                                                       = @{ IPDBNum = 4077; NumPlayers = 4; Type = 'SS'; Theme = 'Supernatural, Horror'; Rating = 0 }
    "JP's Metallica Pro (Stern 2013)"                                                  = @{ IPDBNum = 6028; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 7.9 }
    "JP's Motor Show (Original 2017)"                                                  = @{ IPDBNum = 3631; NumPlayers = 4; Type = 'SS'; Theme = 'Monster Truck Rally, Motorcycles'; Rating = 0 }
    "JP's Nascar Race (Original 2015)"                                                 = @{ IPDBNum = 5093; NumPlayers = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme'; Rating = 6.9 }
    "JP's Seawitch (Stern 1980)"                                                       = @{ IPDBNum = 2089; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "JP's Spider-Man (Original 2018)"                                                  = @{ IPDBNum = 5237; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes'; Rating = 8.1 }
    "JP's Star Trek (Enterprise Limited Edition) (Original 2020)"                      = @{ IPDBNum = 6045; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie'; Rating = 8.9 }
    "JP's Street Fighter II (Original 2016)"                                           = @{ IPDBNum = 2403; NumPlayers = 4; Type = 'SS'; Theme = 'Martial Arts, Video Game'; Rating = 7.2 }
    "JP's Terminator 2 (Original 2020)"                                                = @{ IPDBNum = 2524; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Apocalyptic, Movie'; Rating = 8 }
    "JP's Terminator 3 (Stern 2003)"                                                   = @{ IPDBNum = 4787; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie, Apocalyptic'; Rating = 7.5 }
    "JP's The Avengers (Original 2019)"                                                = @{ IPDBNum = 5938; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes'; Rating = 6.4 }
    "JP's The Lord of the Rings (Stern 2003)"                                          = @{ IPDBNum = 4858; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie'; Rating = 8.1 }
    "JP's The Lost World Jurassic Park (Original 2020)"                                = @{ IPDBNum = 4136; NumPlayers = 6; Type = 'SS'; Theme = 'Dinosaurs, Movie, Licensed Theme'; Rating = 7.2 }
    "JP's The Walking Dead (Original 2021)"                                            = @{ IPDBNum = 6155; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Supernatural, Zombies, TV Show'; Rating = 8 }
    "JP's Transformers (Original 2018)"                                                = @{ IPDBNum = 5709; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie'; Rating = 7.7 }
    "JP's Whoa Nellie! Big Juicy Melons (Original 2022)"                               = @{ IPDBNum = 5863; NumPlayers = 1; Type = 'EM'; Theme = 'Agriculture, Fantasy, Women'; Rating = 0 }
    "Jubilee (Williams 1973)"                                                          = @{ IPDBNum = 1321; NumPlayers = 4; Type = 'EM'; Theme = 'Historical'; Rating = 4.9 }
    "Judge Dredd (Bally 1993)"                                                         = @{ IPDBNum = 1322; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes'; Rating = 8 }
    "Jumping Jack (Gottlieb 1973)"                                                     = @{ IPDBNum = 1329; NumPlayers = 2; Type = 'EM'; Theme = 'Circus, Carnival'; Rating = 7.7 }
    "Jungle (Gottlieb 1972)"                                                           = @{ IPDBNum = 1332; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 6.7 }
    "Jungle King (Gottlieb 1973)"                                                      = @{ IPDBNum = 1336; NumPlayers = 1; Type = 'EM'; Theme = 'Jungle'; Rating = 7.4 }
    "Jungle Life (Gottlieb 1972)"                                                      = @{ IPDBNum = 1337; NumPlayers = 1; Type = 'EM'; Theme = 'Jungle'; Rating = 0 }
    "Jungle Lord (Williams 1981)"                                                      = @{ IPDBNum = 1338; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.7 }
    "Jungle Princess (Gottlieb 1977)"                                                  = @{ IPDBNum = 1339; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.7 }
    "Jungle Queen (Gottlieb 1977)"                                                     = @{ IPDBNum = 1340; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.8 }
    "Junk Yard (Williams 1996)"                                                        = @{ IPDBNum = 4014; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 8 }
    "Jurassic Park (Data East 1993)"                                                   = @{ IPDBNum = 1343; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Dinosaurs'; Rating = 8 }
    "Kick Off (Bally 1977)"                                                            = @{ IPDBNum = 1365; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Soccer'; Rating = 7.5 }
    "Kickoff (Williams 1967)"                                                          = @{ IPDBNum = 1362; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, American Football'; Rating = 0 }
    "King Kong (Data East 1990)"                                                       = @{ IPDBNum = 3194; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Monsters, Licensed Theme, Movie'; Rating = 0 }
    "King Kong (LTD do Brasil 1978)"                                                   = @{ IPDBNum = 5894; NumPlayers = 2; Type = 'SS'; Theme = 'Fantasy, Monsters'; Rating = 0 }
    "King Kool (Gottlieb 1972)"                                                        = @{ IPDBNum = 1371; NumPlayers = 2; Type = 'EM'; Theme = 'Happiness, Music'; Rating = 7.6 }
    "King of Diamonds (Gottlieb 1967)"                                                 = @{ IPDBNum = 1372; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "King Pin (Gottlieb 1973)"                                                         = @{ IPDBNum = 1374; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.8 }
    "King Pin (Williams 1962)"                                                         = @{ IPDBNum = 1375; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.5 }
    "King Rock (Gottlieb 1972)"                                                        = @{ IPDBNum = 1377; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Music'; Rating = 6.9 }
    "King Tut (Bally 1969)"                                                            = @{ IPDBNum = 1378; NumPlayers = 1; Type = 'EM'; Theme = 'Egyptology, Historical'; Rating = 5.3 }
    "Kingdom (J. Esteban 1980)"                                                        = @{ IPDBNum = 5168; NumPlayers = 4; Type = 'EM'; Theme = 'Myth and Legend'; Rating = 0 }
    "Kingpin (Capcom 1996)"                                                            = @{ IPDBNum = 4000; NumPlayers = 4; Type = 'SS'; Theme = 'Police, Mobsters, Crime'; Rating = 6.8 }
    "Kings & Queens (Gottlieb 1965)"                                                   = @{ IPDBNum = 1381; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "Kings of Steel (Bally 1984)"                                                      = @{ IPDBNum = 1382; NumPlayers = 4; Type = 'SS'; Theme = 'Historical, Knights, Cards'; Rating = 7.4 }
    "KISS - PuP-Pack Edition (Bally 1979)"                                             = @{ IPDBNum = 1386; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music'; Rating = 7 }
    "KISS (Bally 1979)"                                                                = @{ IPDBNum = 1386; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music'; Rating = 7 }
    "KISS (Pro) - PuP-Pack Edition (Stern 2015)"                                       = @{ IPDBNum = 6267; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Celebrities, Music'; Rating = 0 }
    "KISS (Pro) (Stern 2015)"                                                          = @{ IPDBNum = 6267; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Celebrities, Music'; Rating = 0 }
    "Klondike (Williams 1971)"                                                         = @{ IPDBNum = 1388; NumPlayers = 1; Type = 'EM'; Theme = 'Canadian West'; Rating = 7.8 }
    "Knock Out (Gottlieb 1950)"                                                        = @{ IPDBNum = 1391; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Boxing'; Rating = 7.2 }
    "Krull (Gottlieb 1983)"                                                            = @{ IPDBNum = 1397; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie'; Rating = 0 }
    "Lady Death (Geiger 1983)"                                                         = @{ IPDBNum = 3972; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Vampires'; Rating = 0 }
    "Lady Luck (Bally 1986)"                                                           = @{ IPDBNum = 1402; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling, Cards, Poker'; Rating = 6.4 }
    "Lady Luck (Recel 1976)"                                                           = @{ IPDBNum = 1405; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.3 }
    "Lady Luck (Taito do Brasil 1980)"                                                 = @{ IPDBNum = 5010; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 0 }
    "Lap by Lap (Inder 1986)"                                                          = @{ IPDBNum = 4098; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 0 }
    "Lariat (Gottlieb 1969)"                                                           = @{ IPDBNum = 1412; NumPlayers = 2; Type = 'EM'; Theme = 'American West'; Rating = 0 }
    "Laser Ball (Williams 1979)"                                                       = @{ IPDBNum = 1413; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 7.2 }
    "Laser Cue (Williams 1984)"                                                        = @{ IPDBNum = 1414; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards, Outer Space, Fantasy'; Rating = 7.4 }
    "Last Action Hero (Data East 1993)"                                                = @{ IPDBNum = 1416; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional, Licensed Theme, Movie'; Rating = 7.9 }
    "Last Lap (Playmatic 1978)"                                                        = @{ IPDBNum = 3207; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 0 }
    "Lawman (Gottlieb 1971)"                                                           = @{ IPDBNum = 1419; NumPlayers = 2; Type = 'EM'; Theme = 'American West, Law Enforcement'; Rating = 7.8 }
    "Lazer Lord (Stern 1982)"                                                          = @{ IPDBNum = 1421; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Lectronamo (Stern 1978)"                                                          = @{ IPDBNum = 1429; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.2 }
    "Lethal Weapon 3 (Data East 1992)"                                                 = @{ IPDBNum = 1433; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Police, Crime, Action, Movie'; Rating = 7.6 }
    "Liberty Bell (Williams 1977)"                                                     = @{ IPDBNum = 1436; NumPlayers = 2; Type = 'EM'; Theme = 'American History, Historical'; Rating = 7.1 }
    "Lightning (Stern 1981)"                                                           = @{ IPDBNum = 1441; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Norse Mythology'; Rating = 7.5 }
    "Lightning Ball (Gottlieb 1959)"                                                   = @{ IPDBNum = 1442; NumPlayers = 1; Type = 'EM'; Theme = 'Dancing, Party'; Rating = 8.5 }
    "Lights...Camera...Action! (Gottlieb 1989)"                                        = @{ IPDBNum = 1445; NumPlayers = 4; Type = 'SS'; Theme = 'Movie, Show Business'; Rating = 7.2 }
    "Line Drive (Williams 1972)"                                                       = @{ IPDBNum = 1447; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.7 }
    "Little Chief (Williams 1975)"                                                     = @{ IPDBNum = 1458; NumPlayers = 4; Type = 'EM'; Theme = 'American West, Native Americans'; Rating = 7.8 }
    "Little Joe (Bally 1972)"                                                          = @{ IPDBNum = 1460; NumPlayers = 4; Type = 'EM'; Theme = 'Playing Dice, Games'; Rating = 7.7 }
    "Loch Ness Monster (Game Plan 1985)"                                               = @{ IPDBNum = 1465; NumPlayers = 4; Type = 'SS'; Theme = 'Monsters'; Rating = 0 }
    "Locomotion (Zaccaria 1981)"                                                       = @{ IPDBNum = 3217; NumPlayers = 4; Type = 'SS'; Theme = 'Travel, Railroad'; Rating = 8.1 }
    "Lord of the Rings, The - Valinor Edition (Stern 2003)"                            = @{ IPDBNum = 4858; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Wizards'; Rating = 8.1 }
    "Lord of the Rings, The (Stern 2003)"                                              = @{ IPDBNum = 4858; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Wizards'; Rating = 8.1 }
    "Lortium (Juegos Populares 1987)"                                                  = @{ IPDBNum = 4104; NumPlayers = 4; Type = 'SS'; Theme = 'Space Fantasy'; Rating = 0 }
    "Lost in Space (Sega 1998)"                                                        = @{ IPDBNum = 4442; NumPlayers = 6; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, TV Show, Robots, Science Fiction, Movie'; Rating = 6.7 }
    "Lost World (Bally 1978)"                                                          = @{ IPDBNum = 1476; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Dinosaurs'; Rating = 7 }
    "Lost World Jurassic Park, The (Sega 1997)"                                        = @{ IPDBNum = 4136; NumPlayers = 6; Type = 'SS'; Theme = 'Dinosaurs, Licensed Theme, Movie'; Rating = 7.2 }
    "Love Bug (Williams 1971)"                                                         = @{ IPDBNum = 1480; NumPlayers = 1; Type = 'EM'; Theme = 'Dancing, Happiness, Music'; Rating = 0 }
    "Luck Smile - 4 Player Edition (Inder 1976)"                                       = @{ IPDBNum = 3886; NumPlayers = 4; Type = 'EM'; Theme = 'Gambling'; Rating = 0 }
    "Luck Smile (Inder 1976)"                                                          = @{ IPDBNum = 3886; NumPlayers = 4; Type = 'EM'; Theme = 'Gambling'; Rating = 0 }
    "Lucky Ace (Williams 1974)"                                                        = @{ IPDBNum = 1483; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.4 }
    "Lucky Hand (Gottlieb 1977)"                                                       = @{ IPDBNum = 1488; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Cards'; Rating = 7.7 }
    "Lucky Seven (Williams 1978)"                                                      = @{ IPDBNum = 1491; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 6.9 }
    "Lucky Strike (Gottlieb 1975)"                                                     = @{ IPDBNum = 1497; NumPlayers = 1; Type = 'EM'; Theme = 'American West, Prospecting'; Rating = 0 }
    "Lucky Strike (Taito do Brasil 1978)"                                              = @{ IPDBNum = 5492; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 0 }
    "Lunelle (Taito do Brasil 1981)"                                                   = @{ IPDBNum = 4591; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Mac Jungle (MAC 1987)"                                                            = @{ IPDBNum = 3187; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Jungle'; Rating = 0 }
    "Mac's Galaxy (MAC 1986)"                                                          = @{ IPDBNum = 3455; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy'; Rating = 0 }
    "Mach 2.0 Two (Spinball S.A.L. 1995)"                                              = @{ IPDBNum = 4617; NumPlayers = 4; Type = 'SS'; Theme = 'Aviation'; Rating = 0 }
    "Machine - Bride of Pin-bot, The (Williams 1991)"                                  = @{ IPDBNum = 1502; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Robots'; Rating = 8 }
    "Mad Race (Playmatic 1985)"                                                        = @{ IPDBNum = 3445; NumPlayers = 4; Type = 'SS'; Theme = 'Motorcycle Racing'; Rating = 0 }
    "Magic (Stern 1979)"                                                               = @{ IPDBNum = 1509; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "Magic Castle (Zaccaria 1984)"                                                     = @{ IPDBNum = 1511; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Vampires'; Rating = 0 }
    "Magic Circle (Bally 1965)"                                                        = @{ IPDBNum = 1513; NumPlayers = 1; Type = 'EM'; Theme = 'Fortune Telling, Dancing, Music'; Rating = 0 }
    "Magic City (Williams 1967)"                                                       = @{ IPDBNum = 1514; NumPlayers = 0; Type = 'EM'; Theme = 'American Places'; Rating = 7.6 }
    "Magic Clock (Williams 1960)"                                                      = @{ IPDBNum = 1515; NumPlayers = 2; Type = 'EM'; Theme = 'Dancing, Outdoor Activities'; Rating = 8.5 }
    "Magic Town (Williams 1967)"                                                       = @{ IPDBNum = 1518; NumPlayers = 0; Type = 'EM'; Theme = 'American Places'; Rating = 0 }
    "Magnotron (Gottlieb 1974)"                                                        = @{ IPDBNum = 1519; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 6.2 }
    "Major League (PAMCO 1934)"                                                        = @{ IPDBNum = 5497; NumPlayers = 0; Type = 'EM'; Theme = 'Sports, Baseball, Flipperless'; Rating = 0 }
    "Maple Leaf, The (Automatic 1932)"                                                 = @{ IPDBNum = 5321; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Marble Queen (Gottlieb 1953)"                                                     = @{ IPDBNum = 1541; NumPlayers = 1; Type = 'EM'; Theme = 'Playing Marbles'; Rating = 0 }
    "Mariner (Bally 1971)"                                                             = @{ IPDBNum = 1546; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Fishing, Scuba Diving'; Rating = 7 }
    "Mario Andretti (Gottlieb 1995)"                                                   = @{ IPDBNum = 3793; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 6.9 }
    "Mars God of War (Gottlieb 1981)"                                                  = @{ IPDBNum = 1549; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology'; Rating = 7.3 }
    "Mars Trek (Sonic 1977)"                                                           = @{ IPDBNum = 1550; NumPlayers = 0; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 7.5 }
    "Martian Queen (LTD do Brasil 1981)"                                               = @{ IPDBNum = 5885; NumPlayers = 0; Type = 'SS'; Theme = 'Aliens, Martians, Fantasy, Outer Space'; Rating = 0 }
    "Mary Shelley's Frankenstein - B&W Edition (Sega 1995)"                            = @{ IPDBNum = 947; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional, Horror'; Rating = 7.9 }
    "Mary Shelley's Frankenstein (Sega 1995)"                                          = @{ IPDBNum = 947; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional, Horror'; Rating = 7.9 }
    "Masquerade (Gottlieb 1966)"                                                       = @{ IPDBNum = 1553; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Dancing'; Rating = 7.5 }
    "Mata Hari (Bally 1978)"                                                           = @{ IPDBNum = 4501; NumPlayers = 4; Type = 'SS'; Theme = 'Historical, Espionage'; Rating = 7.8 }
    "Maverick (Data East 1994)"                                                        = @{ IPDBNum = 1561; NumPlayers = 0; Type = 'SS'; Theme = 'Cards, Gambling, Celebrities, Fictional, Licensed Theme, American West, Movie'; Rating = 7.5 }
    "Medieval Madness - B&W Edition (Williams 1997)"                                   = @{ IPDBNum = 4032; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons'; Rating = 8.3 }
    "Medieval Madness - Redux Edition (Williams 1997)"                                 = @{ IPDBNum = 4032; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons'; Rating = 8.3 }
    "Medieval Madness - Remake Edition (Williams 1997)"                                = @{ IPDBNum = 4032; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons'; Rating = 8.3 }
    "Medieval Madness (Williams 1997)"                                                 = @{ IPDBNum = 4032; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons'; Rating = 8.3 }
    "Medusa (Bally 1981)"                                                              = @{ IPDBNum = 1565; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 7.5 }
    "Melody (Gottlieb 1967)"                                                           = @{ IPDBNum = 1566; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing'; Rating = 7.7 }
    "Mermaid (Gottlieb 1951)"                                                          = @{ IPDBNum = 1574; NumPlayers = 1; Type = 'EM'; Theme = 'Fishing, Sports'; Rating = 0 }
    "Merry-Go-Round (Gottlieb 1960)"                                                   = @{ IPDBNum = 1578; NumPlayers = 2; Type = 'EM'; Theme = 'Amusement Park'; Rating = 0 }
    "Metal Man (Inder 1992)"                                                           = @{ IPDBNum = 4092; NumPlayers = 0; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Metallica - Master of Puppets (Original 2020)"                                    = @{ IPDBNum = 6030; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Heavy Metal'; Rating = 7.4 }
    "Metallica (Premium Monsters) - Christmas Edition (Stern 2013)"                    = @{ IPDBNum = 6030; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Heavy Metal'; Rating = 7.4 }
    "Metallica (Premium Monsters) (Stern 2013)"                                        = @{ IPDBNum = 6030; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Heavy Metal'; Rating = 7.4 }
    "Meteor (Stern 1979)"                                                              = @{ IPDBNum = 1580; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Licensed Theme'; Rating = 7.6 }
    "Meteor (Taito do Brasil 1979)"                                                    = @{ IPDBNum = 4571; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Metropolis (Maresa 1982)"                                                         = @{ IPDBNum = 5732; NumPlayers = 0; Type = 'EM'; Theme = 'Fantasy, Outer Space, Science Fiction'; Rating = 0 }
    "Mibs (Gottlieb 1969)"                                                             = @{ IPDBNum = 1589; NumPlayers = 1; Type = 'EM'; Theme = 'Playing Marbles'; Rating = 7.1 }
    "Michael Jordan - Black Cat Edition (Data East 1992)"                              = @{ IPDBNum = 3425; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball'; Rating = 0 }
    "Michael Jordan (Data East 1992)"                                                  = @{ IPDBNum = 3425; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball'; Rating = 0 }
    "Middle Earth (Atari 1978)"                                                        = @{ IPDBNum = 1590; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 6.4 }
    "Midget Hi-Ball (Peo 1932)"                                                        = @{ IPDBNum = 4657; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Millionaire (Williams 1987)"                                                      = @{ IPDBNum = 1597; NumPlayers = 4; Type = 'SS'; Theme = 'Affluence, Money'; Rating = 7 }
    "Mini Cycle (Gottlieb 1970)"                                                       = @{ IPDBNum = 1604; NumPlayers = 2; Type = 'EM'; Theme = 'Motorcycles'; Rating = 0 }
    "Mini Golf (Williams 1964)"                                                        = @{ IPDBNum = 3434; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Golf'; Rating = 0 }
    "Mini Pool (Gottlieb 1969)"                                                        = @{ IPDBNum = 1605; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 7.7 }
    "Mini-Baseball (Chicago Coin 1972)"                                                = @{ IPDBNum = 5985; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball, Flipperless'; Rating = 0 }
    "Miss World (Geiger 1982)"                                                         = @{ IPDBNum = 3970; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Miss-O (Williams 1969)"                                                           = @{ IPDBNum = 1612; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 6.8 }
    "Mississippi (Recreativos Franco 1973)"                                            = @{ IPDBNum = 5955; NumPlayers = 1; Type = 'EM'; Theme = 'American Places, Cards, Gambling'; Rating = 0 }
    "Monaco (Segasa 1977)"                                                             = @{ IPDBNum = 1614; NumPlayers = 0; Type = 'EM'; Theme = 'World Places, Sports, Happiness, Recreation, Water Skiing, Swimming, Aquatic'; Rating = 7.8 }
    "Monday Night Football (Data East 1989)"                                           = @{ IPDBNum = 1616; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 7.3 }
    "Monopoly (Stern 2001)"                                                            = @{ IPDBNum = 4505; NumPlayers = 4; Type = 'SS'; Theme = 'Board Games, Licensed Theme'; Rating = 7.3 }
    "Monster Bash (Williams 1998)"                                                     = @{ IPDBNum = 4441; NumPlayers = 4; Type = 'SS'; Theme = 'Horror, Licensed Theme'; Rating = 8.2 }
    "Monte Carlo (Bally 1973)"                                                         = @{ IPDBNum = 1621; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.7 }
    "Monte Carlo (Gottlieb 1987)"                                                      = @{ IPDBNum = 1622; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 7 }
    "Moon Light (Inder 1987)"                                                          = @{ IPDBNum = 4416; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Moon Shot (Chicago Coin 1969)"                                                    = @{ IPDBNum = 1628; NumPlayers = 0; Type = 'EM'; Theme = 'Outer Space'; Rating = 0 }
    "Moon Walking Dead, The (Original 2017)"                                           = @{ IPDBNum = 6156; NumPlayers = 4; Type = 'SS'; Theme = 'Supernatural, Zombies'; Rating = 7.4 }
    "Motordome (Bally 1986)"                                                           = @{ IPDBNum = 1633; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross'; Rating = 6.6 }
    "Moulin Rouge (Williams 1965)"                                                     = @{ IPDBNum = 1634; NumPlayers = 1; Type = 'EM'; Theme = 'Adventure, Foreign Peoples'; Rating = 7.6 }
    "Mousin' Around! (Bally 1989)"                                                     = @{ IPDBNum = 1635; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure'; Rating = 7.8 }
    "Mr. & Mrs. Pac-Man Pinball (Bally 1982)"                                          = @{ IPDBNum = 1639; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Video Game'; Rating = 7 }
    "Mr. Black (Taito do Brasil 1984)"                                                 = @{ IPDBNum = 4586; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Mr. Evil (Recel 1978)"                                                            = @{ IPDBNum = 1638; NumPlayers = 1; Type = 'EM'; Theme = 'Fictional Characters, Mythology, Horror'; Rating = 0 }
    "Mundial 90 (Inder 1990)"                                                          = @{ IPDBNum = 4094; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 0 }
    "Mustang (Gottlieb 1977)"                                                          = @{ IPDBNum = 1645; NumPlayers = 2; Type = 'EM'; Theme = 'American West'; Rating = 7.2 }
    "Mustang (Limited Edition) (Stern 2014)"                                           = @{ IPDBNum = 6100; NumPlayers = 4; Type = 'SS'; Theme = 'Cars, Travel, Licensed Theme'; Rating = 0 }
    "Mystery Castle (Alvin G. 1993)"                                                   = @{ IPDBNum = 1647; NumPlayers = 4; Type = 'SS'; Theme = 'Horror, Supernatural'; Rating = 7.2 }
    "Mystic (Bally 1980)"                                                              = @{ IPDBNum = 1650; NumPlayers = 4; Type = 'SS'; Theme = 'Circus, Carnival, Magic'; Rating = 6.8 }
    "Nags (Williams 1960)"                                                             = @{ IPDBNum = 1654; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 7.5 }
    "Nairobi (Maresa 1966)"                                                            = @{ IPDBNum = 6229; NumPlayers = 1; Type = 'EM'; Theme = 'Hunting, Safari, World Places'; Rating = 0 }
    "NASCAR - Dale Jr. (Stern 2005)"                                                   = @{ IPDBNum = 5093; NumPlayers = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme'; Rating = 6.9 }
    "NASCAR - Grand Prix (Stern 2005)"                                                 = @{ IPDBNum = 5093; NumPlayers = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme'; Rating = 6.9 }
    "NASCAR (Stern 2005)"                                                              = @{ IPDBNum = 5093; NumPlayers = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme'; Rating = 6.9 }
    "Nautilus (Playmatic 1984)"                                                        = @{ IPDBNum = 822; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 0 }
    "NBA (Stern 2009)"                                                                 = @{ IPDBNum = 5442; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball, Licensed'; Rating = 7.3 }
    "NBA Fastbreak (Bally 1997)"                                                       = @{ IPDBNum = 4023; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball, Licensed'; Rating = 7.7 }
    "NBA Mac (MAC 1986)"                                                               = @{ IPDBNum = 4606; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball'; Rating = 0 }
    "Nemesis (Peyper 1986)"                                                            = @{ IPDBNum = 4880; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Neptune (Gottlieb 1978)"                                                          = @{ IPDBNum = 1662; NumPlayers = 1; Type = 'EM'; Theme = 'Mythology'; Rating = 7.7 }
    "New Wave (Bell Games 1985)"                                                       = @{ IPDBNum = 3482; NumPlayers = 4; Type = 'SS'; Theme = 'Music'; Rating = 0 }
    "New World (Playmatic 1976)"                                                       = @{ IPDBNum = 1672; NumPlayers = 4; Type = 'EM'; Theme = 'Historical'; Rating = 0 }
    "New York (Gottlieb 1976)"                                                         = @{ IPDBNum = 1673; NumPlayers = 2; Type = 'EM'; Theme = 'American Places, Historical'; Rating = 0 }
    "NFL - 49ers Edition (Stern 2001)"                                                 = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Bears Edition (Stern 2001)"                                                 = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Bengals Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Bills Edition (Stern 2001)"                                                 = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Broncos Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Browns Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Buccaneers Edition (Stern 2001)"                                            = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Cardinals Edition (Stern 2001)"                                             = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Chargers Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Chiefs Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Colts Edition (Stern 2001)"                                                 = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Commanders Edition (Stern 2001)"                                            = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Cowboys Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Dolphins Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Eagles Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Falcons Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Giants Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Jaguars Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Jets Edition (Stern 2001)"                                                  = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Lions Edition (Stern 2001)"                                                 = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Packers Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Panthers Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Patriots Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Raiders Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Rams Edition (Stern 2001)"                                                  = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Ravens Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Redskins Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Saints Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Seahawks Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Steelers Edition (Stern 2001)"                                              = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Texans Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Titans Edition (Stern 2001)"                                                = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL - Vikings Edition (Stern 2001)"                                               = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "NFL (Stern 2001)"                                                                 = @{ IPDBNum = 4540; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 0 }
    "Night Moves (International Concepts 1989)"                                        = @{ IPDBNum = 3507; NumPlayers = 4; Type = 'SS'; Theme = 'Adult, Nightlife'; Rating = 7.3 }
    "Night Rider (Bally 1977)"                                                         = @{ IPDBNum = 1677; NumPlayers = 4; Type = 'EM'; Theme = 'Travel, Transportation, Truck Driving'; Rating = 7.7 }
    "Nine Ball (Stern 1980)"                                                           = @{ IPDBNum = 1678; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 7.2 }
    "Nip-It (Bally 1973)"                                                              = @{ IPDBNum = 1680; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Fishing, Aquatic'; Rating = 7.6 }
    "Nitro Ground Shaker (Bally 1980)"                                                 = @{ IPDBNum = 1682; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 7.8 }
    "No Fear - Dangerous Sports (Williams 1995)"                                       = @{ IPDBNum = 2852; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Licensed Theme, Motorcycles, Cars'; Rating = 7.7 }
    "No Good Gofers (Williams 1997)"                                                   = @{ IPDBNum = 4338; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Golf'; Rating = 8 }
    "North Pole (Playmatic 1967)"                                                      = @{ IPDBNum = 6310; NumPlayers = 1; Type = 'EM'; Theme = 'World Places'; Rating = 0 }
    "North Star (Gottlieb 1964)"                                                       = @{ IPDBNum = 1683; NumPlayers = 1; Type = 'EM'; Theme = 'World Places'; Rating = 7.7 }
    "Now (Gottlieb 1971)"                                                              = @{ IPDBNum = 1685; NumPlayers = 4; Type = 'EM'; Theme = 'Psychedelic'; Rating = 5.9 }
    "Nudge-It (Gottlieb 1990)"                                                         = @{ IPDBNum = 3454; NumPlayers = 1; Type = 'SS'; Theme = 'Prospecting'; Rating = 0 }
    "Nudgy (Bally 1947)"                                                               = @{ IPDBNum = 1686; NumPlayers = 1; Type = 'EM'; Theme = 'Flipperless'; Rating = 0 }
    "Nugent (Stern 1978)"                                                              = @{ IPDBNum = 1687; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Music'; Rating = 6.4 }
    "Oba-Oba (Taito do Brasil 1979)"                                                   = @{ IPDBNum = 4572; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Dancing'; Rating = 0 }
    "Odin Deluxe (Sonic 1985)"                                                         = @{ IPDBNum = 3448; NumPlayers = 4; Type = 'SS'; Theme = 'Norse Mythology'; Rating = 0 }
    "Odisea Paris-Dakar (Peyper 1987)"                                                 = @{ IPDBNum = 4879; NumPlayers = 4; Type = 'SS'; Theme = 'Car Rally, Motorcycle Racing'; Rating = 0 }
    "Old Chicago (Bally 1976)"                                                         = @{ IPDBNum = 1704; NumPlayers = 4; Type = 'EM'; Theme = 'Historical, American Places'; Rating = 7.5 }
    "Old Coney Island! (Game Plan 1979)"                                               = @{ IPDBNum = 553; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival'; Rating = 0 }
    "Olympics (Chicago Coin 1975)"                                                     = @{ IPDBNum = 1711; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Olympic Games'; Rating = 0 }
    "Olympics (Gottlieb 1962)"                                                         = @{ IPDBNum = 1714; NumPlayers = 1; Type = 'EM'; Theme = 'Olympic Games, Sports'; Rating = 6.9 }
    "Olympus (Juegos Populares 1986)"                                                  = @{ IPDBNum = 5140; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology'; Rating = 0 }
    "On Beam (Bally 1969)"                                                             = @{ IPDBNum = 1715; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.3 }
    "Op-Pop-Pop (Bally 1969)"                                                          = @{ IPDBNum = 1722; NumPlayers = 1; Type = 'EM'; Theme = 'Psychedelic Art'; Rating = 7 }
    "Operation Thunder (Gottlieb 1992)"                                                = @{ IPDBNum = 1721; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 7.7 }
    "Orbit (Gottlieb 1971)"                                                            = @{ IPDBNum = 1724; NumPlayers = 4; Type = 'EM'; Theme = 'Outer Space'; Rating = 6.2 }
    "Orbitor 1 (Stern 1982)"                                                           = @{ IPDBNum = 1725; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 5.9 }
    "Out of Sight (Gottlieb 1974)"                                                     = @{ IPDBNum = 1727; NumPlayers = 2; Type = 'EM'; Theme = 'Psychedelic'; Rating = 7.7 }
    "Outer Space (Gottlieb 1972)"                                                      = @{ IPDBNum = 1728; NumPlayers = 2; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.8 }
    "OXO (Williams 1973)"                                                              = @{ IPDBNum = 1733; NumPlayers = 4; Type = 'EM'; Theme = 'Board Games, Tic-Tac-Toe'; Rating = 8 }
    "Pabst Can Crusher, The (Stern 2016)"                                              = @{ IPDBNum = 6335; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Drinking, Beer'; Rating = 0 }
    "Paddock (Williams 1969)"                                                          = @{ IPDBNum = 1735; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 7.4 }
    "Palace Guard (Gottlieb 1968)"                                                     = @{ IPDBNum = 1737; NumPlayers = 1; Type = 'EM'; Theme = 'World Places, Historical'; Rating = 7.5 }
    "Panthera (Gottlieb 1980)"                                                         = @{ IPDBNum = 1745; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 6.8 }
    "Paradise (Gottlieb 1965)"                                                         = @{ IPDBNum = 1752; NumPlayers = 2; Type = 'EM'; Theme = 'Hawaii'; Rating = 7.6 }
    "Paragon (Bally 1979)"                                                             = @{ IPDBNum = 1755; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.9 }
    "Party Animal (Bally 1987)"                                                        = @{ IPDBNum = 1763; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness, Celebration'; Rating = 7 }
    "Party Zone, The (Bally 1991)"                                                     = @{ IPDBNum = 1764; NumPlayers = 4; Type = 'SS'; Theme = 'Happiness'; Rating = 7.7 }
    "Pat Hand (Williams 1975)"                                                         = @{ IPDBNum = 1767; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7 }
    "Paul Bunyan (Gottlieb 1968)"                                                      = @{ IPDBNum = 1768; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy, Mythology'; Rating = 7.4 }
    "Pennant Fever (Williams 1984)"                                                    = @{ IPDBNum = 3335; NumPlayers = 2; Type = 'SS'; Theme = 'Sports, Baseball'; Rating = 0 }
    "Petaco (Juegos Populares 1984)"                                                   = @{ IPDBNum = 4883; NumPlayers = 0; Type = 'SS'; Theme = 'Music, People'; Rating = 0 }
    "Petaco 2 (Juegos Populares 1985)"                                                 = @{ IPDBNum = 5257; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Singing, Dancing'; Rating = 0 }
    "Phantom Haus (Williams 1996)"                                                     = @{ IPDBNum = 6840; NumPlayers = 1; Type = 'PM'; Theme = 'Haunted House'; Rating = 0 }
    "Phantom of the Opera (Data East 1990)"                                            = @{ IPDBNum = 1777; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Singing'; Rating = 7.2 }
    "Pharaoh - Dead Rise (Original 2019)"                                              = @{ IPDBNum = 1778; NumPlayers = 4; Type = 'SS'; Theme = 'Historical'; Rating = 7.2 }
    "Pharaoh (Williams 1981)"                                                          = @{ IPDBNum = 1778; NumPlayers = 4; Type = 'SS'; Theme = 'Historical'; Rating = 7.2 }
    "Phase II (J. Esteban 1975)"                                                       = @{ IPDBNum = 5787; NumPlayers = 0; Type = 'EM'; Theme = 'Mysticism'; Rating = 0 }
    "Phoenix (Williams 1978)"                                                          = @{ IPDBNum = 1780; NumPlayers = 0; Type = 'SS'; Theme = 'Mythology'; Rating = 7.2 }
    "PIN-BOT (Williams 1986)"                                                          = @{ IPDBNum = 1796; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Outer Space'; Rating = 8 }
    "Pin-Up (Gottlieb 1975)"                                                           = @{ IPDBNum = 1789; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.6 }
    "Pinball (EM) (Stern 1977)"                                                        = @{ IPDBNum = 1792; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Pinball'; Rating = 0 }
    "Pinball (SS) (Stern 1977)"                                                        = @{ IPDBNum = 4694; NumPlayers = 4; Type = 'SS'; Theme = 'Pinball, Sports'; Rating = 7.5 }
    "Pinball Action (Tekhan 1985)"                                                     = @{ IPDBNum = 5252; NumPlayers = 2; Type = 'SS'; Theme = ''; Rating = 0 }
    "Pinball Champ '82 (Zaccaria 1982)"                                                = @{ IPDBNum = 1794; NumPlayers = 4; Type = 'SS'; Theme = 'Pinball'; Rating = 0 }
    "Pinball Lizard (Game Plan 1980)"                                                  = @{ IPDBNum = 1464; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.1 }
    "Pinball Magic (Capcom 1995)"                                                      = @{ IPDBNum = 3596; NumPlayers = 4; Type = 'SS'; Theme = 'Show Business, Magic'; Rating = 8 }
    "Pinball Pool (Gottlieb 1979)"                                                     = @{ IPDBNum = 1795; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 7.4 }
    "Pinball Squared (Gottlieb 1984)"                                                  = @{ IPDBNum = 5341; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Pink Panther (Gottlieb 1981)"                                                     = @{ IPDBNum = 1800; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional'; Rating = 7 }
    "Pioneer (Gottlieb 1976)"                                                          = @{ IPDBNum = 1802; NumPlayers = 2; Type = 'EM'; Theme = 'American History'; Rating = 7.3 }
    "Pipeline (Gottlieb 1981)"                                                         = @{ IPDBNum = 5327; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Pirate Gold (Chicago Coin 1969)"                                                  = @{ IPDBNum = 1804; NumPlayers = 1; Type = 'EM'; Theme = 'Pirates, Nautical, Treasure'; Rating = 0 }
    "Pirates of the Caribbean (Stern 2006)"                                            = @{ IPDBNum = 5163; NumPlayers = 4; Type = 'SS'; Theme = 'Pirates, Licensed Theme, Movie'; Rating = 7.6 }
    "Pistol Poker (Alvin G. 1993)"                                                     = @{ IPDBNum = 1805; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 6.9 }
    "Pit Stop (Williams 1968)"                                                         = @{ IPDBNum = 1806; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Auto Racing'; Rating = 6.8 }
    "Planets (Williams 1971)"                                                          = @{ IPDBNum = 1811; NumPlayers = 2; Type = 'EM'; Theme = 'Astrology'; Rating = 0 }
    "Play Pool (Gottlieb 1972)"                                                        = @{ IPDBNum = 1819; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 0 }
    "Playball (Gottlieb 1971)"                                                         = @{ IPDBNum = 1816; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 6.9 }
    "Playboy - Definitive Edition (Bally 1978)"                                        = @{ IPDBNum = 1823; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Adult'; Rating = 7.6 }
    "Playboy (Bally 1978)"                                                             = @{ IPDBNum = 1823; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Adult'; Rating = 7.6 }
    "Playboy 35th Anniversary (Data East 1989)"                                        = @{ IPDBNum = 1822; NumPlayers = 0; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Adult'; Rating = 6.9 }
    "PlayMates (Gottlieb 1968)"                                                        = @{ IPDBNum = 1828; NumPlayers = 1; Type = 'EM'; Theme = 'Happiness, Board Games, Dominoes'; Rating = 0 }
    "Pokerino (Williams 1978)"                                                         = @{ IPDBNum = 1839; NumPlayers = 0; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 5.8 }
    "Polar Explorer (Taito do Brasil 1983)"                                            = @{ IPDBNum = 4588; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Pole Position (Sonic 1987)"                                                       = @{ IPDBNum = 3322; NumPlayers = 4; Type = 'SS'; Theme = 'Cars, Auto Racing'; Rating = 0 }
    "Police Force (Williams 1989)"                                                     = @{ IPDBNum = 1841; NumPlayers = 0; Type = 'SS'; Theme = 'Police, Crime'; Rating = 7.6 }
    "Polo (Gottlieb 1970)"                                                             = @{ IPDBNum = 1843; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Polo'; Rating = 0 }
    "Pool Sharks (Bally 1990)"                                                         = @{ IPDBNum = 1848; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Billiards'; Rating = 7.1 }
    "Pop-A-Card (Gottlieb 1972)"                                                       = @{ IPDBNum = 1849; NumPlayers = 1; Type = 'EM'; Theme = 'Cards'; Rating = 7.7 }
    "Popeye Saves the Earth (Bally 1994)"                                              = @{ IPDBNum = 1851; NumPlayers = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme'; Rating = 7.4 }
    "Poseidon (Gottlieb 1978)"                                                         = @{ IPDBNum = 1852; NumPlayers = 1; Type = 'EM'; Theme = 'Mythology, Aquatic'; Rating = 0 }
    "Post Time (Williams 1969)"                                                        = @{ IPDBNum = 1853; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 7.7 }
    "Primus (Stern 2018)"                                                              = @{ IPDBNum = 6610; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Singing'; Rating = 0 }
    "Pro Pool (Gottlieb 1973)"                                                         = @{ IPDBNum = 1866; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 7.7 }
    "Pro-Football (Gottlieb 1973)"                                                     = @{ IPDBNum = 1865; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, American Football'; Rating = 7.6 }
    "Prospector (Sonic 1977)"                                                          = @{ IPDBNum = 1871; NumPlayers = 4; Type = 'EM'; Theme = 'Comedy, American West, Prospecting'; Rating = 7.4 }
    "Psychedelic (Gottlieb 1970)"                                                      = @{ IPDBNum = 1873; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing, Dancing, Psychedelic'; Rating = 0 }
    "Punchy the Clown (Alvin G. 1993)"                                                 = @{ IPDBNum = 3508; NumPlayers = 1; Type = 'SS'; Theme = 'Circus'; Rating = 0 }
    "Punk! (Gottlieb 1982)"                                                            = @{ IPDBNum = 1877; NumPlayers = 4; Type = 'SS'; Theme = 'Music'; Rating = 0 }
    "Pyramid (Gottlieb 1978)"                                                          = @{ IPDBNum = 1881; NumPlayers = 2; Type = 'EM'; Theme = 'World Places'; Rating = 0 }
    "Queen of Hearts (Gottlieb 1952)"                                                  = @{ IPDBNum = 1891; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "Quick Draw (Gottlieb 1975)"                                                       = @{ IPDBNum = 1893; NumPlayers = 2; Type = 'EM'; Theme = 'American West'; Rating = 7.7 }
    "Quicksilver (Stern 1980)"                                                         = @{ IPDBNum = 1895; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "Rack 'Em Up! (Gottlieb 1983)"                                                     = @{ IPDBNum = 1902; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 7.2 }
    "Rack-A-Ball (Gottlieb 1962)"                                                      = @{ IPDBNum = 1903; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Billiards'; Rating = 6.7 }
    "Radical! (Bally 1990)"                                                            = @{ IPDBNum = 1904; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Skateboarding'; Rating = 7.8 }
    "Radical! (prototype) (Bally 1990)"                                                = @{ IPDBNum = 1904; NumPlayers = 4; Type = 'SS'; Theme = 'Skateboarding, Sports'; Rating = 7.8 }
    "Raid, The (Playmatic 1984)"                                                       = @{ IPDBNum = 3511; NumPlayers = 4; Type = 'SS'; Theme = 'Aviation, Combat, Science Fiction, Aliens'; Rating = 0 }
    "Rainbow (Gottlieb 1956)"                                                          = @{ IPDBNum = 1911; NumPlayers = 1; Type = 'EM'; Theme = 'American West'; Rating = 8.6 }
    "Rally (Taito do Brasil 1980)"                                                     = @{ IPDBNum = 4581; NumPlayers = 4; Type = 'SS'; Theme = 'Auto Racing, Car Rally'; Rating = 0 }
    "Rambo (Original 2019)"                                                            = @{ IPDBNum = 1922; NumPlayers = 4; Type = 'SS'; Theme = 'Movie'; Rating = 5.9 }
    "Rancho (Gottlieb 1966)"                                                           = @{ IPDBNum = 1917; NumPlayers = 1; Type = 'EM'; Theme = 'American West'; Rating = 0 }
    "Rancho (Williams 1976)"                                                           = @{ IPDBNum = 1918; NumPlayers = 2; Type = 'EM'; Theme = 'American West'; Rating = 7.6 }
    "Rapid Fire (Bally 1982)"                                                          = @{ IPDBNum = 3568; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Aliens, Combat'; Rating = 0 }
    "Raven (Gottlieb 1986)"                                                            = @{ IPDBNum = 1922; NumPlayers = 4; Type = 'SS'; Theme = 'Combat'; Rating = 5.9 }
    "Rawhide (Stern 1977)"                                                             = @{ IPDBNum = 3545; NumPlayers = 0; Type = 'EM'; Theme = 'American West'; Rating = 0 }
    "Ready...Aim...Fire! (Gottlieb 1983)"                                              = @{ IPDBNum = 1924; NumPlayers = 4; Type = 'SS'; Theme = 'Shooting Gallery'; Rating = 0 }
    "Red & Ted's Road Show (Williams 1994)"                                            = @{ IPDBNum = 1972; NumPlayers = 4; Type = 'SS'; Theme = 'Travel'; Rating = 8 }
    "Red Baron (Chicago Coin 1975)"                                                    = @{ IPDBNum = 1933; NumPlayers = 2; Type = 'EM'; Theme = 'Adventure, Combat'; Rating = 4.4 }
    "Rescue 911 (Gottlieb 1994)"                                                       = @{ IPDBNum = 1951; NumPlayers = 4; Type = 'SS'; Theme = 'Rescue, Fire Fighting, Police'; Rating = 7.6 }
    "Rey de Diamantes (Petaco 1967)"                                                   = @{ IPDBNum = 4368; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Rider's Surf (Jocmatic 1986)"                                                     = @{ IPDBNum = 4102; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Surfing, Aquatic'; Rating = 0 }
    "Ripley's Believe it or Not! (Stern 2004)"                                         = @{ IPDBNum = 4917; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Exploration, Adventure'; Rating = 8 }
    "Riverboat Gambler (Williams 1990)"                                                = @{ IPDBNum = 1966; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 7.3 }
    "Ro Go (Bally 1974)"                                                               = @{ IPDBNum = 1969; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy, Norse Mythology'; Rating = 5.2 }
    "Road Kings (Williams 1986)"                                                       = @{ IPDBNum = 1970; NumPlayers = 4; Type = 'SS'; Theme = 'Apocalyptic, Motorcycles'; Rating = 7.5 }
    "Road Race (Gottlieb 1969)"                                                        = @{ IPDBNum = 1971; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Auto Racing'; Rating = 7 }
    "Road Runner (Atari 1979)"                                                         = @{ IPDBNum = 3517; NumPlayers = 2; Type = 'SS'; Theme = 'Licensed Theme, Kids, Cartoon, American West'; Rating = 0 }
    "Robo-War (Gottlieb 1988)"                                                         = @{ IPDBNum = 1975; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Robots, Combat'; Rating = 7 }
    "Robocop (Data East 1989)"                                                         = @{ IPDBNum = 1976; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Crime, Police'; Rating = 7.3 }
    "Robot (Zaccaria 1985)"                                                            = @{ IPDBNum = 1977; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Robots'; Rating = 8.4 }
    "Rock (Gottlieb 1985)"                                                             = @{ IPDBNum = 1978; NumPlayers = 4; Type = 'SS'; Theme = 'Music'; Rating = 6.4 }
    "Rock 2500 (Playmatic 1985)"                                                       = @{ IPDBNum = 3538; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Music, Women'; Rating = 0 }
    "Rock Encore (Gottlieb 1986)"                                                      = @{ IPDBNum = 1979; NumPlayers = 4; Type = 'SS'; Theme = 'Music, Singing'; Rating = 0 }
    "Rock Star (Gottlieb 1978)"                                                        = @{ IPDBNum = 1983; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing'; Rating = 0 }
    "Rocket III (Bally 1967)"                                                          = @{ IPDBNum = 1989; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.5 }
    "RockMakers (Bally 1968)"                                                          = @{ IPDBNum = 1980; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 6.9 }
    "Rocky (Gottlieb 1982)"                                                            = @{ IPDBNum = 1993; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Boxing, Licensed Theme, Movie'; Rating = 7 }
    "Roller Coaster (Gottlieb 1971)"                                                   = @{ IPDBNum = 2002; NumPlayers = 2; Type = 'EM'; Theme = 'Amusement Park, Roller Coasters'; Rating = 7.4 }
    "Roller Derby (Bally 1960)"                                                        = @{ IPDBNum = 2003; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Roller Skating'; Rating = 0 }
    "Roller Disco (Gottlieb 1980)"                                                     = @{ IPDBNum = 2005; NumPlayers = 4; Type = 'SS'; Theme = 'Roller Skating, Music, Happiness'; Rating = 7.3 }
    "RollerCoaster Tycoon (Stern 2002)"                                                = @{ IPDBNum = 4536; NumPlayers = 4; Type = 'SS'; Theme = 'Roller Coasters, Licensed Theme, Amusement Park'; Rating = 7.1 }
    "Rollergames (Williams 1990)"                                                      = @{ IPDBNum = 2006; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Roller Derby, Roller Skating, Licensed Theme'; Rating = 7.5 }
    "Rollet (Barok Co 1931)"                                                           = @{ IPDBNum = 2007; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Rolling Stones - B&W Edition (Bally 1980)"                                        = @{ IPDBNum = 2010; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Music, Rock n roll'; Rating = 6.8 }
    "Rolling Stones (Bally 1980)"                                                      = @{ IPDBNum = 2010; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Music, Rock n roll'; Rating = 6.8 }
    "Rolling Stones, The (Stern 2011)"                                                 = @{ IPDBNum = 5668; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Music'; Rating = 6.8 }
    "Roman Victory (Taito do Brasil 1977)"                                             = @{ IPDBNum = 5493; NumPlayers = 4; Type = 'SS'; Theme = 'Roman History'; Rating = 0 }
    "Royal Flush (Gottlieb 1976)"                                                      = @{ IPDBNum = 2035; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.8 }
    "Royal Flush Deluxe (Gottlieb 1983)"                                               = @{ IPDBNum = 2036; NumPlayers = 4; Type = 'SS'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Royal Guard (Gottlieb 1968)"                                                      = @{ IPDBNum = 2037; NumPlayers = 1; Type = 'EM'; Theme = 'World Places, Historical'; Rating = 7.7 }
    "Royal Pair - 2 Pop Bumper Edition (Gottlieb 1974)"                                = @{ IPDBNum = 2038; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Royal Pair (Gottlieb 1974)"                                                       = @{ IPDBNum = 2038; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Running Horse (Inder 1976)"                                                       = @{ IPDBNum = 4414; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 0 }
    "Safe Cracker (Bally 1996)"                                                        = @{ IPDBNum = 3782; NumPlayers = 4; Type = 'SS'; Theme = 'Crime, Money, Police'; Rating = 7.9 }
    "San Francisco (Williams 1964)"                                                    = @{ IPDBNum = 2049; NumPlayers = 2; Type = 'EM'; Theme = 'American Places'; Rating = 0 }
    "Satin Doll (Williams 1975)"                                                       = @{ IPDBNum = 2057; NumPlayers = 2; Type = 'EM'; Theme = 'Music, Singing'; Rating = 5.9 }
    "Scared Stiff (Bally 1996)"                                                        = @{ IPDBNum = 3915; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Horror, Supernatural'; Rating = 8.3 }
    "Schuss (Rally 1968)"                                                              = @{ IPDBNum = 3541; NumPlayers = 0; Type = 'EM'; Theme = 'Sports, Skiing'; Rating = 0 }
    "Scorpion (Williams 1980)"                                                         = @{ IPDBNum = 2067; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.3 }
    "Scram! (Hutchison 1932)"                                                          = @{ IPDBNum = 5138; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Scramble (Tecnoplay 1987)"                                                        = @{ IPDBNum = 3557; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross'; Rating = 0 }
    "Scuba (Gottlieb 1970)"                                                            = @{ IPDBNum = 2077; NumPlayers = 2; Type = 'EM'; Theme = 'Mermaids, Mythology, Scuba Diving, Swimming, Aquatic'; Rating = 7.8 }
    "Sea Jockeys (Williams 1951)"                                                      = @{ IPDBNum = 2084; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Aquatic'; Rating = 0 }
    "Sea Ray (Bally 1971)"                                                             = @{ IPDBNum = 2085; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Aquatic, Fishing, Scuba Diving'; Rating = 7.2 }
    "Seawitch (Stern 1980)"                                                            = @{ IPDBNum = 2089; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.4 }
    "Secret Service (Data East 1988)"                                                  = @{ IPDBNum = 2090; NumPlayers = 4; Type = 'SS'; Theme = 'Police, Espionage'; Rating = 7.5 }
    "Seven Winner (Inder 1973)"                                                        = @{ IPDBNum = 4407; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Playing Dice, Games'; Rating = 0 }
    "Sexy Girl - Nude Edition (Arkon 1980)"                                            = @{ IPDBNum = 2106; NumPlayers = 4; Type = 'SS'; Theme = 'Women, Adult'; Rating = 0 }
    "Sexy Girl (Arkon 1980)"                                                           = @{ IPDBNum = 2106; NumPlayers = 4; Type = 'SS'; Theme = 'Women, Adult'; Rating = 0 }
    "Shadow, The (Bally 1994)"                                                         = @{ IPDBNum = 2528; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Detective, Supernatural, Comics, Movie'; Rating = 8.1 }
    "Shamrock (Inder 1977)"                                                            = @{ IPDBNum = 5717; NumPlayers = 0; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Shangri-La (Williams 1967)"                                                       = @{ IPDBNum = 2110; NumPlayers = 4; Type = 'EM'; Theme = 'World Places'; Rating = 7.6 }
    "Shaq Attaq (Gottlieb 1995)"                                                       = @{ IPDBNum = 2874; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Basketball, Celebrities, Licensed Theme'; Rating = 7.3 }
    "Shark (Taito do Brasil 1982)"                                                     = @{ IPDBNum = 4582; NumPlayers = 4; Type = 'SS'; Theme = 'Boats, Scuba Diving, Nautical, Aquatic'; Rating = 0 }
    "Sharkey's Shootout (Stern 2000)"                                                  = @{ IPDBNum = 4492; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Billiards'; Rating = 7.1 }
    "Sharp Shooter II (Game Plan 1983)"                                                = @{ IPDBNum = 2114; NumPlayers = 4; Type = 'SS'; Theme = 'American West'; Rating = 0 }
    "Sharpshooter (Game Plan 1979)"                                                    = @{ IPDBNum = 2113; NumPlayers = 4; Type = 'SS'; Theme = 'American West'; Rating = 7.4 }
    "Sheriff (Gottlieb 1971)"                                                          = @{ IPDBNum = 2116; NumPlayers = 4; Type = 'EM'; Theme = 'American West, Law Enforcement'; Rating = 7.6 }
    "Sherokee (Rowamet 1978)"                                                          = @{ IPDBNum = 6707; NumPlayers = 0; Type = 'EM'; Theme = 'American West, Historical, Native Americans'; Rating = 0 }
    "Ship Ahoy (Gottlieb 1976)"                                                        = @{ IPDBNum = 2119; NumPlayers = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical'; Rating = 7.6 }
    "Ship-Mates (Gottlieb 1964)"                                                       = @{ IPDBNum = 2120; NumPlayers = 4; Type = 'EM'; Theme = 'Nautical'; Rating = 7.1 }
    "Shock (Taito do Brasil 1979)"                                                     = @{ IPDBNum = 4573; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Shooting Star (Junior) (Daval 1934)"                                              = @{ IPDBNum = 6021; NumPlayers = 1; Type = 'EM'; Theme = 'Flipperless'; Rating = 0 }
    "Shooting the Rapids (Zaccaria 1979)"                                              = @{ IPDBNum = 3606; NumPlayers = 4; Type = 'SS'; Theme = 'Canoeing, Native Americans, Water Sports'; Rating = 0 }
    "Shrek (Stern 2008)"                                                               = @{ IPDBNum = 5301; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Fictional, Animation, Movie, Kids'; Rating = 7.6 }
    "Silver Cup (Genco 1933)"                                                          = @{ IPDBNum = 2146; NumPlayers = 1; Type = 'PM'; Theme = ''; Rating = 0 }
    "Silver Slugger (Gottlieb 1990)"                                                   = @{ IPDBNum = 2152; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Baseball'; Rating = 7.4 }
    "Silverball Mania (Bally 1980)"                                                    = @{ IPDBNum = 2156; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Pinball, Fantasy'; Rating = 7.4 }
    "Simpsons Pinball Party, The (Stern 2003)"                                         = @{ IPDBNum = 4674; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Animation, Cartoon, Comedy'; Rating = 8 }
    "Simpsons Treehouse of Horror, The - Starlion Edition (Original 2020)"             = @{ IPDBNum = 4674; NumPlayers = 4; Type = 'SS'; Theme = 'TV Show'; Rating = 8 }
    "Simpsons Treehouse of Horror, The (Original 2020)"                                = @{ IPDBNum = 4674; NumPlayers = 4; Type = 'SS'; Theme = 'TV Show'; Rating = 8 }
    "Simpsons, The (Data East 1990)"                                                   = @{ IPDBNum = 2158; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Animation, Cartoon, Comedy'; Rating = 7.5 }
    "Sinbad (Gottlieb 1978)"                                                           = @{ IPDBNum = 2159; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 7.6 }
    "Sing Along (Gottlieb 1967)"                                                       = @{ IPDBNum = 2160; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing'; Rating = 7.8 }
    "Sir Lancelot (Peyper 1994)"                                                       = @{ IPDBNum = 4949; NumPlayers = 0; Type = 'SS'; Theme = 'Medieval, Fantasy'; Rating = 0 }
    "Sittin' Pretty (Gottlieb 1958)"                                                   = @{ IPDBNum = 2164; NumPlayers = 1; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 7.8 }
    "Six Million Dollar Man, The (Bally 1978)"                                         = @{ IPDBNum = 2165; NumPlayers = 6; Type = 'SS'; Theme = 'TV Show, Fictional, Licensed Theme'; Rating = 7.3 }
    "Skateball (Bally 1980)"                                                           = @{ IPDBNum = 2170; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Skateboarding'; Rating = 7.5 }
    "Skateboard (Inder 1980)"                                                          = @{ IPDBNum = 4479; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Skateboarding'; Rating = 0 }
    "Skipper (Gottlieb 1969)"                                                          = @{ IPDBNum = 2189; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Nautical'; Rating = 6.7 }
    "Sky Jump (Gottlieb 1974)"                                                         = @{ IPDBNum = 2195; NumPlayers = 1; Type = 'EM'; Theme = 'Parachuting, Sports, Skydiving'; Rating = 7.5 }
    "Sky Kings (Bally 1974)"                                                           = @{ IPDBNum = 2196; NumPlayers = 1; Type = 'EM'; Theme = 'Parachuting, Skydiving, Sports'; Rating = 7.1 }
    "Sky Ride (Genco 1933)"                                                            = @{ IPDBNum = 2200; NumPlayers = 1; Type = 'PM'; Theme = 'Flipperless'; Rating = 0 }
    "Sky-Line (Gottlieb 1965)"                                                         = @{ IPDBNum = 3240; NumPlayers = 1; Type = 'EM'; Theme = 'Nightclubs, Nightlife'; Rating = 7.7 }
    "Skylab (Williams 1974)"                                                           = @{ IPDBNum = 2202; NumPlayers = 1; Type = 'EM'; Theme = 'Space Exploration'; Rating = 6.8 }
    "Skyrocket (Bally 1971)"                                                           = @{ IPDBNum = 2204; NumPlayers = 2; Type = 'EM'; Theme = 'Happiness, Circus, Carnival'; Rating = 7.6 }
    "Skyscraper (Bally 1934)"                                                          = @{ IPDBNum = 2205; NumPlayers = 1; Type = 'EM'; Theme = 'City Skyline'; Rating = 0 }
    "Skyway (Williams 1954)"                                                           = @{ IPDBNum = 2206; NumPlayers = 1; Type = 'EM'; Theme = 'Space Age, Travel, Aquatic, Women'; Rating = 0 }
    "Sleic Pin-BALL - Cabinet Edition (Sleic 1994)"                                    = @{ IPDBNum = 4620; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Sleic Pin-BALL - Desktop Edition (Sleic 1994)"                                    = @{ IPDBNum = 4620; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Sleic Pin-BALL (Sleic 1994)"                                                      = @{ IPDBNum = 4620; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Slick Chick (Gottlieb 1963)"                                                      = @{ IPDBNum = 2208; NumPlayers = 1; Type = 'EM'; Theme = 'Women'; Rating = 7.8 }
    "Smart Set (Williams 1969)"                                                        = @{ IPDBNum = 2215; NumPlayers = 4; Type = 'EM'; Theme = 'Boats, Recreation, Affluence, Aquatic'; Rating = 7.1 }
    "Snake Machine (Taito do Brasil 1982)"                                             = @{ IPDBNum = 4585; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Snooker (Gottlieb 1985)"                                                          = @{ IPDBNum = 5343; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Snow Derby (Gottlieb 1970)"                                                       = @{ IPDBNum = 2229; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Skiing, Snowmobiling'; Rating = 7.6 }
    "Snow Queen (Gottlieb 1970)"                                                       = @{ IPDBNum = 2230; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Skiing'; Rating = 7.2 }
    "Soccer (Gottlieb 1975)"                                                           = @{ IPDBNum = 2233; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Soccer'; Rating = 7.4 }
    "Soccer (Williams 1964)"                                                           = @{ IPDBNum = 2232; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Soccer'; Rating = 7.2 }
    "Soccer Kings (Zaccaria 1982)"                                                     = @{ IPDBNum = 2235; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 0 }
    "Solar City (Gottlieb 1977)"                                                       = @{ IPDBNum = 2237; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.5 }
    "Solar Fire (Williams 1981)"                                                       = @{ IPDBNum = 2238; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy'; Rating = 7.4 }
    "Solar Ride (Electromatic 1982)"                                                   = @{ IPDBNum = 5696; NumPlayers = 4; Type = 'EM'; Theme = 'Outer Space, Space Fantasy'; Rating = 0 }
    "Solar Ride (Gottlieb 1979)"                                                       = @{ IPDBNum = 2239; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.5 }
    "Solar Wars (Sonic 1986)"                                                          = @{ IPDBNum = 3273; NumPlayers = 0; Type = 'SS'; Theme = ''; Rating = 0 }
    "Solids N Stripes (Williams 1971)"                                                 = @{ IPDBNum = 2240; NumPlayers = 2; Type = 'EM'; Theme = 'Billiards'; Rating = 6.3 }
    "Solitaire (Gottlieb 1967)"                                                        = @{ IPDBNum = 2241; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Sopranos, The (Stern 2005)"                                                       = @{ IPDBNum = 5053; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Mobsters, Crime, TV Show'; Rating = 7.4 }
    "Sorcerer (Williams 1985)"                                                         = @{ IPDBNum = 2242; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Wizards, Magic, Dragons'; Rating = 7.8 }
    "Sound Stage (Chicago Coin 1976)"                                                  = @{ IPDBNum = 2243; NumPlayers = 2; Type = 'EM'; Theme = 'Music, Singing'; Rating = 5.8 }
    "South Park (Sega 1999)"                                                           = @{ IPDBNum = 4444; NumPlayers = 6; Type = 'SS'; Theme = 'Licensed Theme, Animation, Comedy, Movie, TV Show'; Rating = 7 }
    "Space Gambler (Playmatic 1978)"                                                   = @{ IPDBNum = 2250; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction'; Rating = 0 }
    "Space Invaders (Bally 1980)"                                                      = @{ IPDBNum = 2252; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 7.7 }
    "Space Mission (Williams 1976)"                                                    = @{ IPDBNum = 2253; NumPlayers = 4; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.8 }
    "Space Odyssey (Williams 1976)"                                                    = @{ IPDBNum = 2254; NumPlayers = 2; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.5 }
    "Space Orbit (Gottlieb 1972)"                                                      = @{ IPDBNum = 2255; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space'; Rating = 0 }
    "Space Patrol (Taito do Brasil 1978)"                                              = @{ IPDBNum = 6582; NumPlayers = 0; Type = 'EM'; Theme = 'Outer Space'; Rating = 0 }
    "Space Poker (LTD do Brasil 1982)"                                                 = @{ IPDBNum = 5886; NumPlayers = 2; Type = 'SS'; Theme = 'Science Fiction, Outer Space, Cards, Gambling'; Rating = 0 }
    "Space Rider (Geiger 1980)"                                                        = @{ IPDBNum = 4018; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Space Riders (Atari 1978)"                                                        = @{ IPDBNum = 2258; NumPlayers = 4; Type = 'SS'; Theme = 'Motorcycles, Travel, Futuristic Racing, Science Fiction'; Rating = 7.3 }
    "Space Shuttle (Taito do Brasil 1985)"                                             = @{ IPDBNum = 4583; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Space Shuttle (Williams 1984)"                                                    = @{ IPDBNum = 2260; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.7 }
    "Space Station (Williams 1987)"                                                    = @{ IPDBNum = 2261; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.7 }
    "Space Time (Bally 1972)"                                                          = @{ IPDBNum = 2262; NumPlayers = 4; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.4 }
    "Space Train (MAC 1987)"                                                           = @{ IPDBNum = 3895; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Space Walk (Gottlieb 1979)"                                                       = @{ IPDBNum = 2263; NumPlayers = 2; Type = 'EM'; Theme = 'Outer Space'; Rating = 0 }
    "Spanish Eyes (Williams 1972)"                                                     = @{ IPDBNum = 2265; NumPlayers = 1; Type = 'EM'; Theme = 'Dancing, Music, Women, World Places'; Rating = 7.7 }
    "Spark Plugs (Williams 1951)"                                                      = @{ IPDBNum = 2267; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 0 }
    "Speakeasy (Bally 1982)"                                                           = @{ IPDBNum = 2270; NumPlayers = 2; Type = 'SS'; Theme = 'American History'; Rating = 7.2 }
    "Speakeasy (Playmatic 1977)"                                                       = @{ IPDBNum = 2269; NumPlayers = 4; Type = 'EM'; Theme = 'American History, Cards, Gambling'; Rating = 7.1 }
    "Speakeasy 4 (Bally 1982)"                                                         = @{ IPDBNum = 4342; NumPlayers = 4; Type = 'SS'; Theme = 'American History'; Rating = 0 }
    "Special Force (Bally 1986)"                                                       = @{ IPDBNum = 2272; NumPlayers = 0; Type = 'SS'; Theme = 'Combat'; Rating = 6.6 }
    "Spectrum (Bally 1982)"                                                            = @{ IPDBNum = 2274; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7 }
    "Speed Test (Taito do Brasil 1982)"                                                = @{ IPDBNum = 4589; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 0 }
    "Spider-Man - Classic Edition (Stern 2007)"                                        = @{ IPDBNum = 5237; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed, Comics, Superheroes'; Rating = 8.1 }
    "Spider-Man (Black Suited) (Stern 2007)"                                           = @{ IPDBNum = 5650; NumPlayers = 4; Type = 'SS'; Theme = 'Superheroes'; Rating = 7.6 }
    "Spider-Man (Stern 2007)"                                                          = @{ IPDBNum = 5237; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed, Comics, Superheroes'; Rating = 8.1 }
    "Spider-Man (Vault Edition) - Classic Edition (Stern 2016)"                        = @{ IPDBNum = 6328; NumPlayers = 0; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes'; Rating = 8.5 }
    "Spider-Man (Vault Edition) (Stern 2016)"                                          = @{ IPDBNum = 6328; NumPlayers = 0; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes'; Rating = 8.5 }
    "Spin Out (Gottlieb 1975)"                                                         = @{ IPDBNum = 2286; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Auto Racing'; Rating = 7.4 }
    "Spin Wheel (Gottlieb 1968)"                                                       = @{ IPDBNum = 2287; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Games'; Rating = 6.9 }
    "Spin-A-Card (Gottlieb 1969)"                                                      = @{ IPDBNum = 2288; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.6 }
    "Spinning Wheel (Automaticos 1970)"                                                = @{ IPDBNum = 6402; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling'; Rating = 0 }
    "Spirit (Gottlieb 1982)"                                                           = @{ IPDBNum = 2292; NumPlayers = 4; Type = 'SS'; Theme = 'Supernatural'; Rating = 7.3 }
    "Spirit of 76 (Gottlieb 1975)"                                                     = @{ IPDBNum = 2293; NumPlayers = 4; Type = 'EM'; Theme = 'Historical'; Rating = 7.6 }
    "Split Second (Stern 1981)"                                                        = @{ IPDBNum = 2297; NumPlayers = 4; Type = 'SS'; Theme = 'Carnival, Circus, Happiness'; Rating = 7.1 }
    "Spot a Card (Gottlieb 1960)"                                                      = @{ IPDBNum = 2318; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 8.3 }
    "Spot Pool (Gottlieb 1976)"                                                        = @{ IPDBNum = 2316; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 0 }
    "Spring Break (Gottlieb 1987)"                                                     = @{ IPDBNum = 2324; NumPlayers = 4; Type = 'SS'; Theme = 'Aquatic, Happiness'; Rating = 6.5 }
    "Spy Hunter (Bally 1984)"                                                          = @{ IPDBNum = 2328; NumPlayers = 4; Type = 'SS'; Theme = 'Video Game, Espionage'; Rating = 7.3 }
    "Stampede (Stern 1977)"                                                            = @{ IPDBNum = 5232; NumPlayers = 2; Type = 'EM'; Theme = 'American West'; Rating = 0 }
    "Star Action (Williams 1973)"                                                      = @{ IPDBNum = 2342; NumPlayers = 1; Type = 'EM'; Theme = 'Show Business'; Rating = 7.6 }
    "Star Fire (Playmatic 1985)"                                                       = @{ IPDBNum = 3453; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction'; Rating = 0 }
    "Star Gazer (Stern 1980)"                                                          = @{ IPDBNum = 2346; NumPlayers = 4; Type = 'SS'; Theme = 'Astrology'; Rating = 7.4 }
    "Star God (Zaccaria 1980)"                                                         = @{ IPDBNum = 3458; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Star Light (Williams 1984)"                                                       = @{ IPDBNum = 2362; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy, Wizards'; Rating = 6.9 }
    "Star Pool (Williams 1974)"                                                        = @{ IPDBNum = 2352; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Billiards'; Rating = 6.9 }
    "Star Race (Gottlieb 1980)"                                                        = @{ IPDBNum = 2353; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Outer Space'; Rating = 7.2 }
    "Star Ship (Bally 1976)"                                                           = @{ IPDBNum = 3498; NumPlayers = 2; Type = 'EM'; Theme = 'Space Exploration, Outer Space, Science Fiction'; Rating = 0 }
    "Star Trek - Mirror Universe Edition (Bally 1979)"                                 = @{ IPDBNum = 2355; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie'; Rating = 7.1 }
    "Star Trek - The Next Generation (Williams 1993)"                                  = @{ IPDBNum = 2357; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, TV Show, Space Exploration, Science Fiction'; Rating = 8.3 }
    "Star Trek (Bally 1979)"                                                           = @{ IPDBNum = 2355; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie'; Rating = 7.1 }
    "Star Trek (Data East 1991)"                                                       = @{ IPDBNum = 2356; NumPlayers = 0; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie'; Rating = 7.4 }
    "Star Trek (Enterprise Limited Edition) (Stern 2013)"                              = @{ IPDBNum = 6046; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie'; Rating = 8 }
    "Star Trek (Gottlieb 1971)"                                                        = @{ IPDBNum = 2354; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Star Trip (Game Plan 1979)"                                                       = @{ IPDBNum = 3605; NumPlayers = 0; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Star Wars - The Empire Strikes Back (Hankin 1980)"                                = @{ IPDBNum = 2868; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie'; Rating = 7 }
    "Star Wars (Data East 1992)"                                                       = @{ IPDBNum = 2358; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie'; Rating = 8 }
    "Star Wars (Sonic 1987)"                                                           = @{ IPDBNum = 4513; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie'; Rating = 0 }
    "Star Wars Trilogy Special Edition (Sega 1997)"                                    = @{ IPDBNum = 4054; NumPlayers = 6; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie'; Rating = 7.2 }
    "Star-Jet (Bally 1963)"                                                            = @{ IPDBNum = 2347; NumPlayers = 2; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 7.6 }
    "Stardust (Williams 1971)"                                                         = @{ IPDBNum = 2359; NumPlayers = 4; Type = 'EM'; Theme = 'Happiness, Dancing'; Rating = 7.3 }
    "Stargate (Gottlieb 1995)"                                                         = @{ IPDBNum = 2847; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Mythology, TV Show'; Rating = 8 }
    "Stars (Stern 1978)"                                                               = @{ IPDBNum = 2366; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Exploration'; Rating = 7.4 }
    "Starship Troopers - VPN Edition (Sega 1997)"                                      = @{ IPDBNum = 4341; NumPlayers = 6; Type = 'SS'; Theme = 'Combat, Aliens, Science Fiction, Movie, Licensed Theme'; Rating = 7.8 }
    "Starship Troopers (Sega 1997)"                                                    = @{ IPDBNum = 4341; NumPlayers = 6; Type = 'SS'; Theme = 'Combat, Aliens, Science Fiction, Movie, Licensed Theme'; Rating = 7.8 }
    "Stellar Airship (Geiger 1979)"                                                    = @{ IPDBNum = 4016; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Outer Space'; Rating = 0 }
    "Stellar Wars (Williams 1979)"                                                     = @{ IPDBNum = 2372; NumPlayers = 0; Type = 'SS'; Theme = 'Fantasy, Outer Space, Science Fiction'; Rating = 7.5 }
    "Still Crazy (Williams 1984)"                                                      = @{ IPDBNum = 3730; NumPlayers = 1; Type = 'SS'; Theme = 'American History, Hillbillies, Rural Living'; Rating = 0 }
    "Stingray (Stern 1977)"                                                            = @{ IPDBNum = 2377; NumPlayers = 4; Type = 'SS'; Theme = 'Scuba Diving, Sports, Aquatic'; Rating = 7.3 }
    "Stock Car (Gottlieb 1970)"                                                        = @{ IPDBNum = 2378; NumPlayers = 1; Type = 'EM'; Theme = 'Auto Racing'; Rating = 0 }
    "Straight Flush (Williams 1970)"                                                   = @{ IPDBNum = 2393; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Cards, Poker'; Rating = 6.8 }
    "Strange Science (Bally 1986)"                                                     = @{ IPDBNum = 2396; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.6 }
    "Strange World (Gottlieb 1978)"                                                    = @{ IPDBNum = 2397; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 7.7 }
    "Strato-Flite (Williams 1974)"                                                     = @{ IPDBNum = 2398; NumPlayers = 4; Type = 'EM'; Theme = 'Aviation, Outer Space'; Rating = 7.7 }
    "Street Fighter II (Gottlieb 1993)"                                                = @{ IPDBNum = 2403; NumPlayers = 4; Type = 'SS'; Theme = 'Martial Arts, Video Game'; Rating = 7.2 }
    "Strike (Zaccaria 1978)"                                                           = @{ IPDBNum = 3363; NumPlayers = 1; Type = 'SS'; Theme = 'Bowling'; Rating = 0 }
    "Striker (Gottlieb 1982)"                                                          = @{ IPDBNum = 2405; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 7.5 }
    "Striker Xtreme (Stern 2000)"                                                      = @{ IPDBNum = 4459; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 6.9 }
    "Strikes and Spares (Bally 1978)"                                                  = @{ IPDBNum = 2406; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Bowling'; Rating = 7.7 }
    "Strikes N' Spares (Gottlieb 1995)"                                                = @{ IPDBNum = 4336; NumPlayers = 4; Type = 'SS'; Theme = 'Bowling'; Rating = 6.8 }
    "Strip Joker Poker (Gottlieb 1978)"                                                = @{ IPDBNum = 1306; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Gambling, Adult, Poker'; Rating = 8 }
    "Stripping Funny (Inder 1974)"                                                     = @{ IPDBNum = 4410; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 0 }
    "Student Prince (Williams 1968)"                                                   = @{ IPDBNum = 2408; NumPlayers = 4; Type = 'EM'; Theme = 'Operetta, Musical'; Rating = 7.9 }
    "Sultan (Taito do Brasil 1979)"                                                    = @{ IPDBNum = 5009; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 0 }
    "Summer Time (Williams 1972)"                                                      = @{ IPDBNum = 2415; NumPlayers = 1; Type = 'EM'; Theme = 'Beach, Swimming, Surfing, Water'; Rating = 0 }
    "Super Bowl (Bell Games 1984)"                                                     = @{ IPDBNum = 3399; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football, Tic-Tac-Toe'; Rating = 0 }
    "Super Mario Bros. (Gottlieb 1992)"                                                = @{ IPDBNum = 2435; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed, Kids'; Rating = 7.4 }
    "Super Mario Bros. Mushroom World (Gottlieb 1992)"                                 = @{ IPDBNum = 3427; NumPlayers = 4; Type = 'SS'; Theme = 'Video Game, Kids'; Rating = 7.3 }
    "Super Nova (Game Plan 1980)"                                                      = @{ IPDBNum = 2436; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 0 }
    "Super Orbit (Gottlieb 1983)"                                                      = @{ IPDBNum = 2437; NumPlayers = 0; Type = 'SS'; Theme = 'Outer Space'; Rating = 5.6 }
    "Super Score (Gottlieb 1967)"                                                      = @{ IPDBNum = 2441; NumPlayers = 0; Type = 'EM'; Theme = 'Sports, Pinball'; Rating = 7.7 }
    "Super Soccer (Gottlieb 1975)"                                                     = @{ IPDBNum = 2443; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Soccer'; Rating = 7.3 }
    "Super Spin (Gottlieb 1977)"                                                       = @{ IPDBNum = 2445; NumPlayers = 2; Type = 'EM'; Theme = 'Fantasy, Recreation'; Rating = 7.8 }
    "Super Star (Chicago Coin 1975)"                                                   = @{ IPDBNum = 2447; NumPlayers = 4; Type = 'EM'; Theme = 'Olympic Games, Sports'; Rating = 0 }
    "Super Star (Williams 1972)"                                                       = @{ IPDBNum = 2446; NumPlayers = 1; Type = 'EM'; Theme = 'Music, Singing'; Rating = 7.4 }
    "Super Straight (Sonic 1977)"                                                      = @{ IPDBNum = 2449; NumPlayers = 4; Type = 'EM'; Theme = 'Cards, Poker, Gambling'; Rating = 7.3 }
    "Super-Flite (Williams 1974)"                                                      = @{ IPDBNum = 2452; NumPlayers = 2; Type = 'EM'; Theme = 'Aviation, Outer Space'; Rating = 7.1 }
    "Superman (Atari 1979)"                                                            = @{ IPDBNum = 2454; NumPlayers = 4; Type = 'SS'; Theme = 'Fictional, Licensed Theme, Comics, Superheroes'; Rating = 7.3 }
    "Supersonic (Bally 1979)"                                                          = @{ IPDBNum = 2455; NumPlayers = 4; Type = 'SS'; Theme = 'Aircraft, Historical, Travel'; Rating = 7.2 }
    "Sure Shot (Gottlieb 1976)"                                                        = @{ IPDBNum = 2457; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 7.8 }
    "Sure Shot (Taito do Brasil 1981)"                                                 = @{ IPDBNum = 4574; NumPlayers = 4; Type = 'SS'; Theme = 'Billiards'; Rating = 0 }
    "Surf 'n Safari (Gottlieb 1991)"                                                   = @{ IPDBNum = 2461; NumPlayers = 4; Type = 'SS'; Theme = 'Amusement Park, Aquatic, Safari'; Rating = 7.2 }
    "Surf Champ (Gottlieb 1976)"                                                       = @{ IPDBNum = 2459; NumPlayers = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Happiness, Recreation, Surfing, Swimming'; Rating = 7.7 }
    "Surf Side (Gottlieb 1967)"                                                        = @{ IPDBNum = 2464; NumPlayers = 2; Type = 'EM'; Theme = 'Nautical, Swimming, Sports, Happiness, Aquatic'; Rating = 7.4 }
    "Surfer (Gottlieb 1976)"                                                           = @{ IPDBNum = 2465; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Aquatic, Happiness, Recreation, Surfing, Swimming'; Rating = 7.8 }
    "Sweet Hearts (Gottlieb 1963)"                                                     = @{ IPDBNum = 2474; NumPlayers = 1; Type = 'EM'; Theme = 'Gambling, Cards'; Rating = 7.7 }
    "Sweet Sioux (Gottlieb 1959)"                                                      = @{ IPDBNum = 2475; NumPlayers = 0; Type = 'EM'; Theme = 'Native Americans'; Rating = 0 }
    "Swing-Along (Gottlieb 1963)"                                                      = @{ IPDBNum = 2484; NumPlayers = 2; Type = 'EM'; Theme = 'Music, Dancing'; Rating = 7.3 }
    "Swinger (Williams 1972)"                                                          = @{ IPDBNum = 2485; NumPlayers = 2; Type = 'EM'; Theme = 'Music, Dancing, People, Singing'; Rating = 7.4 }
    "Swords of Fury (Williams 1988)"                                                   = @{ IPDBNum = 2486; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Knights, Wizards, Magic, Medieval'; Rating = 7.9 }
    "T.K.O. (Gottlieb 1979)"                                                           = @{ IPDBNum = 4599; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Boxing'; Rating = 6.5 }
    "Tag-Team Pinball (Gottlieb 1985)"                                                 = @{ IPDBNum = 2489; NumPlayers = 4; Type = 'SS'; Theme = 'Wrestling'; Rating = 7.8 }
    "Tales from the Crypt (Data East 1993)"                                            = @{ IPDBNum = 2493; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Horror'; Rating = 7.9 }
    "Tales of the Arabian Nights (Williams 1996)"                                      = @{ IPDBNum = 3824; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Mythology'; Rating = 8.2 }
    "Tam-Tam (Playmatic 1975)"                                                         = @{ IPDBNum = 2496; NumPlayers = 1; Type = 'EM'; Theme = 'World Culture'; Rating = 0 }
    "Target Alpha (Gottlieb 1976)"                                                     = @{ IPDBNum = 2500; NumPlayers = 4; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 7.7 }
    "Target Pool (Gottlieb 1969)"                                                      = @{ IPDBNum = 2502; NumPlayers = 1; Type = 'EM'; Theme = 'Billiards'; Rating = 7.7 }
    "Taxi - Lola Edition (Williams 1988)"                                              = @{ IPDBNum = 2505; NumPlayers = 4; Type = 'SS'; Theme = 'Cars, Transportation'; Rating = 8 }
    "Taxi (Williams 1988)"                                                             = @{ IPDBNum = 2505; NumPlayers = 4; Type = 'SS'; Theme = 'Cars, Transportation'; Rating = 8 }
    "Teacher's Pet (Williams 1965)"                                                    = @{ IPDBNum = 2506; NumPlayers = 1; Type = 'EM'; Theme = 'Happiness, School'; Rating = 7.7 }
    "Team One (Gottlieb 1977)"                                                         = @{ IPDBNum = 2507; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Soccer'; Rating = 7.6 }
    "Tee'd Off (Gottlieb 1993)"                                                        = @{ IPDBNum = 2508; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Golf'; Rating = 7.5 }
    "Teenage Mutant Ninja Turtles - PuP-Pack Edition (Data East 1991)"                 = @{ IPDBNum = 2509; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Movie, Kids'; Rating = 6.8 }
    "Teenage Mutant Ninja Turtles (Data East 1991)"                                    = @{ IPDBNum = 2509; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Movie, Kids'; Rating = 6.8 }
    "Ten Stars (Zaccaria 1976)"                                                        = @{ IPDBNum = 3373; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Terminator 2 - Judgment Day - Chrome Edition (Williams 1991)"                     = @{ IPDBNum = 2524; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie, Apocalyptic'; Rating = 8 }
    "Terminator 2 - Judgment Day (Williams 1991)"                                      = @{ IPDBNum = 2524; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie, Apocalyptic'; Rating = 8 }
    "Terminator 3 - Rise of the Machines (Stern 2003)"                                 = @{ IPDBNum = 4787; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie, Apocalyptic, Time Travel, Robots'; Rating = 7.5 }
    "Terrific Lake (Sport matic 1987)"                                                 = @{ IPDBNum = 5289; NumPlayers = 4; Type = 'SS'; Theme = 'Horror'; Rating = 0 }
    "Texas Ranger (Gottlieb 1972)"                                                     = @{ IPDBNum = 2527; NumPlayers = 1; Type = 'EM'; Theme = 'American West, Law Enforcement'; Rating = 0 }
    "Theatre of Magic (Bally 1995)"                                                    = @{ IPDBNum = 2845; NumPlayers = 4; Type = 'SS'; Theme = 'Show Business, Magic'; Rating = 8.3 }
    "Thunder Man (Apple Time 1987)"                                                    = @{ IPDBNum = 4666; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Fictional'; Rating = 0 }
    "Thunderbirds - Are Go! (Original 2022)"                                           = @{ IPDBNum = 6617; NumPlayers = 0; Type = 'SS'; Theme = 'Adventure, Aviation, Science Fiction, TV Show, Kids'; Rating = 0 }
    "Thunderbirds (Original 2022)"                                                     = @{ IPDBNum = 6617; NumPlayers = 0; Type = 'SS'; Theme = 'Adventure, Aviation, Science Fiction, TV Show, Kids'; Rating = 0 }
    "Ticket Tac Toe (Williams 1996)"                                                   = @{ IPDBNum = 4334; NumPlayers = 1; Type = 'SS'; Theme = 'Children''s Games, Kids'; Rating = 0 }
    "Tidal Wave (Gottlieb 1981)"                                                       = @{ IPDBNum = 5326; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Tiger (Gottlieb 1975)"                                                            = @{ IPDBNum = 2560; NumPlayers = 1; Type = 'EM'; Theme = 'Circus'; Rating = 0 }
    "Time Fantasy (Williams 1983)"                                                     = @{ IPDBNum = 2563; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Time Travel'; Rating = 7 }
    "Time Line (Gottlieb 1980)"                                                        = @{ IPDBNum = 2564; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Fantasy, Time Travel'; Rating = 7.5 }
    "Time Machine (Data East 1988)"                                                    = @{ IPDBNum = 2565; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Time Travel'; Rating = 7.9 }
    "Time Machine (LTD do Brasil 1984)"                                                = @{ IPDBNum = 5887; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Time Travel'; Rating = 0 }
    "Time Machine (Zaccaria 1983)"                                                     = @{ IPDBNum = 3494; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Fantasy, Science Fiction, Time Travel'; Rating = 6.4 }
    "Time Tunnel (Bally 1971)"                                                         = @{ IPDBNum = 2566; NumPlayers = 4; Type = 'EM'; Theme = 'TV Show, Fantasy, Time Travel'; Rating = 0 }
    "Time Warp (Williams 1979)"                                                        = @{ IPDBNum = 2568; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology, Science Fiction, Time Travel'; Rating = 7.5 }
    "Tiro''s (Maresa 1969)"                                                            = @{ IPDBNum = 5818; NumPlayers = 1; Type = 'EM'; Theme = 'Amusement Park'; Rating = 0 }
    "Titan (Gottlieb 1982)"                                                            = @{ IPDBNum = 5330; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "Titan (Taito do Brasil 1981)"                                                     = @{ IPDBNum = 4587; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Title Fight (Gottlieb 1990)"                                                      = @{ IPDBNum = 2573; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Boxing'; Rating = 6.9 }
    "Toledo (Williams 1975)"                                                           = @{ IPDBNum = 2577; NumPlayers = 2; Type = 'EM'; Theme = 'World Places'; Rating = 6.7 }
    "Top Card (Gottlieb 1974)"                                                         = @{ IPDBNum = 2580; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 7.7 }
    "Top Hand (Gottlieb 1973)"                                                         = @{ IPDBNum = 2582; NumPlayers = 1; Type = 'EM'; Theme = 'Cards, Gambling'; Rating = 0 }
    "Top Score (Gottlieb 1975)"                                                        = @{ IPDBNum = 2589; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.8 }
    "Topaz (Inder 1979)"                                                               = @{ IPDBNum = 4477; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy, Women'; Rating = 0 }
    "Torch (Gottlieb 1980)"                                                            = @{ IPDBNum = 2595; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Olympic Games'; Rating = 6.9 }
    "Torpedo Alley (Data East 1988)"                                                   = @{ IPDBNum = 2603; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Combat, Nautical'; Rating = 7.3 }
    "Torpedo!! (Petaco 1976)"                                                          = @{ IPDBNum = 4371; NumPlayers = 1; Type = 'EM'; Theme = 'Adventure, Combat, Nautical'; Rating = 0 }
    "Total Nuclear Annihilation - Welcome to the Future Edition (Spooky Pinball 2017)" = @{ IPDBNum = 6444; NumPlayers = 4; Type = 'SS'; Theme = 'Combat, Science Fiction, Apocalyptic'; Rating = 7.9 }
    "Total Nuclear Annihilation (Spooky Pinball 2017)"                                 = @{ IPDBNum = 6444; NumPlayers = 4; Type = 'SS'; Theme = 'Combat, Science Fiction, Apocalyptic'; Rating = 7.9 }
    "Totem (Gottlieb 1979)"                                                            = @{ IPDBNum = 2607; NumPlayers = 4; Type = 'SS'; Theme = 'American West, Native Americans'; Rating = 7.3 }
    "Touchdown (Gottlieb 1984)"                                                        = @{ IPDBNum = 2610; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, American Football'; Rating = 6.8 }
    "Touchdown (Williams 1967)"                                                        = @{ IPDBNum = 2609; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, American Football'; Rating = 7.8 }
    "Trade Winds (Williams 1962)"                                                      = @{ IPDBNum = 2621; NumPlayers = 1; Type = 'EM'; Theme = 'Boats, Nautical, Aquatic'; Rating = 7.8 }
    "Trailer (Playmatic 1985)"                                                         = @{ IPDBNum = 3276; NumPlayers = 4; Type = 'SS'; Theme = 'Travel, Transportation, Truck Driving'; Rating = 0 }
    "Tramway (Williams 1973)"                                                          = @{ IPDBNum = 2627; NumPlayers = 2; Type = 'EM'; Theme = 'Travel, Tramways, Transportation'; Rating = 0 }
    "Transformers (Pro) (Stern 2011)"                                                  = @{ IPDBNum = 5709; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie, Robots'; Rating = 7.7 }
    "Transporter the Rescue (Bally 1989)"                                              = @{ IPDBNum = 2630; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space'; Rating = 7.4 }
    "Travel Time (Williams 1972)"                                                      = @{ IPDBNum = 2636; NumPlayers = 1; Type = 'EM'; Theme = 'Beach, Swimming, Surfing, Travel, Water'; Rating = 7.6 }
    "Tri Zone (Williams 1979)"                                                         = @{ IPDBNum = 2641; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 6.9 }
    "Trick Shooter (LTD do Brasil 1980)"                                               = @{ IPDBNum = 5888; NumPlayers = 0; Type = 'SS'; Theme = 'American West'; Rating = 0 }
    "Trident (Stern 1979)"                                                             = @{ IPDBNum = 2644; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology'; Rating = 7 }
    "Triple Action (Williams 1973)"                                                    = @{ IPDBNum = 2648; NumPlayers = 1; Type = 'EM'; Theme = 'Show Business'; Rating = 7.6 }
    "Triple Strike (Williams 1975)"                                                    = @{ IPDBNum = 2652; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Bowling'; Rating = 7.7 }
    "Triple X (Williams 1973)"                                                         = @{ IPDBNum = 6497; NumPlayers = 2; Type = 'EM'; Theme = 'Board Games, Tic-Tac-Toe'; Rating = 0 }
    "TRON Classic - PuP-Pack Edition (Original 2018)"                                  = @{ IPDBNum = 1745; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Movie'; Rating = 6.8 }
    "TRON Classic (Original 2018)"                                                     = @{ IPDBNum = 1745; NumPlayers = 4; Type = 'SS'; Theme = 'Science Fiction, Movie'; Rating = 6.8 }
    "Tropic Fun (Williams 1973)"                                                       = @{ IPDBNum = 2660; NumPlayers = 1; Type = 'EM'; Theme = 'Beach, Recreation, Water'; Rating = 0 }
    "Truck Stop (Bally 1988)"                                                          = @{ IPDBNum = 2667; NumPlayers = 4; Type = 'SS'; Theme = 'American Places, Travel, Transportation, Truck Driving'; Rating = 7.5 }
    "Twilight Zone - B&W Edition (Bally 1993)"                                         = @{ IPDBNum = 2684; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Supernatural, Licensed Theme, TV Show'; Rating = 8.4 }
    "Twilight Zone (Bally 1993)"                                                       = @{ IPDBNum = 2684; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Supernatural, Licensed Theme, TV Show'; Rating = 8.4 }
    "Twinky (Chicago Coin 1967)"                                                       = @{ IPDBNum = 2692; NumPlayers = 2; Type = 'EM'; Theme = 'Modeling, Television'; Rating = 7.1 }
    "Twister (Sega 1996)"                                                              = @{ IPDBNum = 3976; NumPlayers = 6; Type = 'SS'; Theme = 'Movie, Licensed Theme, Weather'; Rating = 7.1 }
    "TX-Sector (Gottlieb 1988)"                                                        = @{ IPDBNum = 2699; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction'; Rating = 7.3 }
    "Tyrannosaurus (Gottlieb 1985)"                                                    = @{ IPDBNum = 5344; NumPlayers = 4; Type = 'SS'; Theme = ''; Rating = 0 }
    "U-Boat 65 (Nuova Bell Games 1988)"                                                = @{ IPDBNum = 3736; NumPlayers = 4; Type = 'SS'; Theme = 'Combat, Nautical'; Rating = 0 }
    "Underwater (Recel 1976)"                                                          = @{ IPDBNum = 2702; NumPlayers = 4; Type = 'EM'; Theme = 'Adventure, Combat, Nautical'; Rating = 0 }
    "Universe (Gottlieb 1959)"                                                         = @{ IPDBNum = 2705; NumPlayers = 1; Type = 'EM'; Theme = 'Outer Space'; Rating = 7.5 }
    "Universe (Zaccaria 1976)"                                                         = @{ IPDBNum = 2706; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 0 }
    "V.1 (IDSA 1986)"                                                                  = @{ IPDBNum = 5022; NumPlayers = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy'; Rating = 0 }
    "Vampire (Bally 1971)"                                                             = @{ IPDBNum = 2716; NumPlayers = 2; Type = 'EM'; Theme = 'Vampires'; Rating = 6 }
    "Vector (Bally 1982)"                                                              = @{ IPDBNum = 2723; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy, Sports'; Rating = 7.4 }
    "Vegas (Gottlieb 1990)"                                                            = @{ IPDBNum = 2724; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 7.6 }
    "Vegas (Taito do Brasil 1980)"                                                     = @{ IPDBNum = 4575; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling'; Rating = 0 }
    "Verne's World (Spinball S.A.L. 1996)"                                             = @{ IPDBNum = 4619; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Fantasy, Fictional'; Rating = 0 }
    "Victory (Gottlieb 1987)"                                                          = @{ IPDBNum = 2733; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Auto Racing'; Rating = 7 }
    "Viking (Bally 1980)"                                                              = @{ IPDBNum = 2737; NumPlayers = 4; Type = 'SS'; Theme = 'Norse Mythology, Historical'; Rating = 7.5 }
    "Viking King (LTD do Brasil 1979)"                                                 = @{ IPDBNum = 5895; NumPlayers = 2; Type = 'SS'; Theme = 'Norse Mythology'; Rating = 0 }
    "Viper (Stern 1981)"                                                               = @{ IPDBNum = 2739; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Viper Night Drivin' (Sega 1998)"                                                  = @{ IPDBNum = 4359; NumPlayers = 6; Type = 'SS'; Theme = 'Cars, Licensed Theme, Auto Racing'; Rating = 6.8 }
    "Volcano (Gottlieb 1981)"                                                          = @{ IPDBNum = 2742; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.5 }
    "Volley (Gottlieb 1976)"                                                           = @{ IPDBNum = 2743; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Tennis'; Rating = 7.7 }
    "Volley (Taito do Brasil 1981)"                                                    = @{ IPDBNum = 5494; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Volleyball'; Rating = 0 }
    "Voltan Escapes Cosmic Doom (Bally 1979)"                                          = @{ IPDBNum = 2744; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 6.9 }
    "Vortex (Taito do Brasil 1983)"                                                    = @{ IPDBNum = 4576; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Vulcan (Gottlieb 1977)"                                                           = @{ IPDBNum = 2745; NumPlayers = 4; Type = 'EM'; Theme = 'Roman Mythology'; Rating = 7.7 }
    "Vulcan IV (Rowamet 1982)"                                                         = @{ IPDBNum = 5169; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology'; Rating = 0 }
    "Walking Dead (Limited Edition), The (Stern 2014)"                                 = @{ IPDBNum = 6156; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Supernatural, Zombies, TV Show, Horror'; Rating = 7.4 }
    "Walking Dead (Pro), The (Stern 2014)"                                             = @{ IPDBNum = 6155; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Supernatural, Zombies, TV Show, Horror'; Rating = 8 }
    "Walkyria (Joctronic 1986)"                                                        = @{ IPDBNum = 5556; NumPlayers = 4; Type = 'SS'; Theme = 'Norse Mythology'; Rating = 0 }
    "Warlok (Williams 1982)"                                                           = @{ IPDBNum = 2754; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Waterworld (Gottlieb 1995)"                                                       = @{ IPDBNum = 3793; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Apocalyptic'; Rating = 6.9 }
    "Wheel (Maresa 1974)"                                                              = @{ IPDBNum = 4644; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Auto Racing, Cars'; Rating = 0 }
    "Wheel of Fortune (Stern 2007)"                                                    = @{ IPDBNum = 5254; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Game Show'; Rating = 7.4 }
    "Whirl-Wind (Gottlieb 1958)"                                                       = @{ IPDBNum = 2760; NumPlayers = 2; Type = 'EM'; Theme = 'Dancing'; Rating = 0 }
    "Whirlwind (Williams 1990)"                                                        = @{ IPDBNum = 2765; NumPlayers = 4; Type = 'SS'; Theme = 'Adventure, Weather'; Rating = 8 }
    "White Water (Williams 1993)"                                                      = @{ IPDBNum = 2768; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Rafting, Aquatic, Mythology'; Rating = 8.2 }
    "WHO dunnit (Bally 1995)"                                                          = @{ IPDBNum = 3685; NumPlayers = 4; Type = 'SS'; Theme = 'Detective, Crime'; Rating = 7.9 }
    "Who's Tommy Pinball Wizard, The (Data East 1994)"                                 = @{ IPDBNum = 2579; NumPlayers = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Musical, Movie, Rock n roll'; Rating = 8 }
    "Whoa Nellie! Big Juicy Melons - Nude Edition (Stern 2015)"                        = @{ IPDBNum = 6252; NumPlayers = 4; Type = 'SS'; Theme = 'Agriculture, Fantasy, Women, Adult'; Rating = 0 }
    "Whoa Nellie! Big Juicy Melons (Stern 2015)"                                       = @{ IPDBNum = 6252; NumPlayers = 4; Type = 'SS'; Theme = 'Agriculture, Fantasy, Women, Adult'; Rating = 0 }
    "Whoa Nellie! Big Juicy Melons (WhizBang Pinball 2011)"                            = @{ IPDBNum = 5863; NumPlayers = 1; Type = 'EM'; Theme = 'Agriculture, Fantasy, Women'; Rating = 0 }
    "Wiggler, The (Bally 1967)"                                                        = @{ IPDBNum = 2777; NumPlayers = 4; Type = 'EM'; Theme = 'Fantasy'; Rating = 7.6 }
    "Wild Card (Williams 1977)"                                                        = @{ IPDBNum = 2778; NumPlayers = 1; Type = 'EM'; Theme = 'American West, Cards, Gambling'; Rating = 7.6 }
    "Wild Fyre (Stern 1978)"                                                           = @{ IPDBNum = 2783; NumPlayers = 4; Type = 'SS'; Theme = 'Historical, Chariot Racing, Roman History'; Rating = 7.6 }
    "Wild Life (Gottlieb 1972)"                                                        = @{ IPDBNum = 2784; NumPlayers = 2; Type = 'EM'; Theme = 'Jungle'; Rating = 6.9 }
    "Wild Wild West (Gottlieb 1969)"                                                   = @{ IPDBNum = 2787; NumPlayers = 2; Type = 'EM'; Theme = 'American West'; Rating = 7.7 }
    "Wimbledon (Electromatic 1978)"                                                    = @{ IPDBNum = 6581; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Tennis'; Rating = 0 }
    "Winner (Williams 1971)"                                                           = @{ IPDBNum = 2792; NumPlayers = 2; Type = 'EM'; Theme = 'Sports, Horse Racing'; Rating = 6.4 }
    "Wipe Out (Gottlieb 1993)"                                                         = @{ IPDBNum = 2799; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Skiing'; Rating = 7.5 }
    "Wizard! (Bally 1975)"                                                             = @{ IPDBNum = 2803; NumPlayers = 4; Type = 'EM'; Theme = 'Licensed Theme'; Rating = 7.7 }
    "Wolf Man (Peyper 1987)"                                                           = @{ IPDBNum = 4435; NumPlayers = 4; Type = 'SS'; Theme = 'Mythology, Horror'; Rating = 0 }
    "Wonderland (Williams 1955)"                                                       = @{ IPDBNum = 2805; NumPlayers = 1; Type = 'EM'; Theme = 'Fictional, Fantasy'; Rating = 0 }
    "World Challenge Soccer (Gottlieb 1994)"                                           = @{ IPDBNum = 2808; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 7 }
    "World Cup (Williams 1978)"                                                        = @{ IPDBNum = 2810; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 6.4 }
    "World Cup Soccer (Bally 1994)"                                                    = @{ IPDBNum = 2811; NumPlayers = 4; Type = 'SS'; Theme = 'Sports, Soccer'; Rating = 8 }
    "World Poker Tour (Stern 2006)"                                                    = @{ IPDBNum = 5134; NumPlayers = 4; Type = 'SS'; Theme = 'Gambling, Cards, Poker, Licensed Theme'; Rating = 7.2 }
    "World Series (Gottlieb 1972)"                                                     = @{ IPDBNum = 2813; NumPlayers = 1; Type = 'EM'; Theme = 'Sports, Baseball'; Rating = 7.6 }
    "World's Fair Jig-Saw (Rock-ola 1933)"                                             = @{ IPDBNum = 1295; NumPlayers = 1; Type = 'PM'; Theme = 'Celebration'; Rating = 0 }
    "WWF Royal Rumble (Data East 1994)"                                                = @{ IPDBNum = 2820; NumPlayers = 4; Type = 'SS'; Theme = 'Licensed, Sports, Wrestling, Comedy, Licensed Theme'; Rating = 7.9 }
    "X Files, The (Sega 1997)"                                                         = @{ IPDBNum = 4137; NumPlayers = 6; Type = 'SS'; Theme = 'Aliens, Conspiracy, Supernatural, Licensed, TV Show'; Rating = 6.7 }
    "X-Men Magneto LE (Stern 2012)"                                                    = @{ IPDBNum = 5823; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes'; Rating = 0 }
    "X-Men Wolverine LE (Stern 2012)"                                                  = @{ IPDBNum = 5824; NumPlayers = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes'; Rating = 8 }
    "X's & O's (Bally 1984)"                                                           = @{ IPDBNum = 2822; NumPlayers = 4; Type = 'SS'; Theme = 'Board Games, Tic-Tac-Toe'; Rating = 6.8 }
    "Xenon (Bally 1980)"                                                               = @{ IPDBNum = 2821; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 7.8 }
    "Yukon (Special) (Williams 1971)"                                                  = @{ IPDBNum = 3533; NumPlayers = 1; Type = 'EM'; Theme = 'Canadian West'; Rating = 0 }
    "Yukon (Williams 1971)"                                                            = @{ IPDBNum = 2829; NumPlayers = 0; Type = 'EM'; Theme = 'Canadian West'; Rating = 0 }
    "Zarza (Taito do Brasil 1982)"                                                     = @{ IPDBNum = 4584; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Zephy (LTD do Brasil 1982)"                                                       = @{ IPDBNum = 4592; NumPlayers = 3; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Zip-A-Doo (Bally 1970)"                                                           = @{ IPDBNum = 2840; NumPlayers = 2; Type = 'EM'; Theme = 'Happiness, Flower Power'; Rating = 7.3 }
    "Zira (Playmatic 1980)"                                                            = @{ IPDBNum = 3584; NumPlayers = 4; Type = 'SS'; Theme = 'Fantasy'; Rating = 0 }
    "Zodiac (Williams 1971)"                                                           = @{ IPDBNum = 2841; NumPlayers = 2; Type = 'EM'; Theme = 'Astrology'; Rating = 6.4 }
}

# =============================================================================
# Write-IncrementedLaunchCount

function Write-IncrementedLaunchCount {
    param ([Parameter(Mandatory)][string]$FileName)

    $count = 1

    if ($script:launchCount.Contains($FileName)) {
        $count = $script:launchCount[$FileName] += 1
    }
    else {
        $script:launchCount.Add($FileName, 1)
    }

    $count
}

#######################################################################################################################

#  ___             _            ___
# |_ _|_ ___ _____| |_____ ___ / __|__ _ _ __  ___
#  | || ' \ V / _ \ / / -_)___| (_ / _` | '  \/ -_)
# |___|_||_\_/\___/_\_\___|    \___\__,_|_|_|_\___|
#

function Invoke-Game {
    Param(
        [Parameter(Mandatory)][Windows.Forms.Button]$LaunchButton,
        [Parameter(Mandatory)][string]$PinballExe,
        [Parameter(Mandatory)][string]$TablePath
    )

    $prevText = $buttonLaunch.Text
    $buttonLaunch.Enabled = $false
    $buttonLaunch.Text = 'Running'

    Write-Verbose "Launching: $tablePath"
    $proc = Start-Process -FilePath $PinballExe -ArgumentList '-ExtMinimized', '-Play', ('"{0}"' -f $TablePath) -NoNewWindow -PassThru

    # Games take a while to load, so show a fake progress bar.
    for ($i = 0; $i -le $progressBar.Maximum - $progressBar.Minimum; $i++) {
        $progressBar.Value = $i
        Start-Sleep -Milliseconds 500
        if ($win32::FindWindow('VPinball', 'Visual Pinball') -ne 0) {
            # Visual Pinball exited immediately. maybe a game crashed or it started quickly.
            break
        }
    }

    Write-Verbose 'Waiting for VPX to exit'
    $proc.WaitForExit()

    $progressBar.Value = 0

    $buttonLaunch.Enabled = $true
    $buttonLaunch.Text = $prevText

    $baseName = [IO.Path]::GetFileNameWithoutExtension((Split-Path -Path $TablePath -Leaf).ToLower())
    $count = Write-IncrementedLaunchCount -FileName $baseName

    # Update listview play count
    $listView.SelectedItems[0].SubItems[$script:colPlayCount].Text = $count

    # Remove this file that's left over after running a game.
    $tableFolder = Split-Path -Parent $TablePath
    Remove-Item "$tableFolder/altsound.log" -ErrorAction SilentlyContinue

    if (Test-Path "$tableFolder/crash.dmp" -PathType Leaf ) {
        Remove-Item "$tableFolder/crash.dmp" -ErrorAction SilentlyContinue
        Remove-Item "$tableFolder/crash.txt" -ErrorAction SilentlyContinue
        # Write-Host -ForegroundColor Red "Table '$baseName' crashed!"
        [Windows.MessageBox]::Show("Table '$baseName' crashed!", 'Warning', 'OK', 'Error') | Out-Null

    }

    Write-Verbose ('VPX (filename: {0}) exited' -f $filename)
}

# =============================================================================
# Invoke-ListRefresh

function Invoke-ListRefresh {
    param(
        [Parameter(Mandatory)][string]$TablePath,
        [Parameter(Mandatory)][object]$listView
    )

    $selectedItemText = $null
    if ($listView.SelectedItems.Count -eq 1) {
        $selectedItemText = $listView.SelectedItems.Text
    }

    $listView.Items.Clear()

    # Read in Read-VpxFileMetadatadatabase
    $vpxFiles = (Get-ChildItem -Recurse -Depth 1 -File -LiteralPath $TablePath -Include '*.vpx').FullName
    $tables = Read-VpxFileMetadata -VpxFiles $vpxFiles
    if ($tables.Count -eq 0) {
        Write-Warning "No tables found in $TablePath"
        return
    }

    foreach ($table in $tables) {
        $listItem = New-Object -TypeName 'Windows.Forms.ListViewItem'
        $listItem.Text = $table.Table
        $listItem.Tag = $table.FileName
        $listItem.SubItems.Add($table.Manufacturer) | Out-Null # $script:colManufacturer
        $listItem.SubItems.Add($table.Year) | Out-Null # $script:colYear
        $listItem.SubItems.Add($table.Details) | Out-Null # $script:colDetails
        $launchCount = $script:launchCount[[IO.Path]::GetFileNameWithoutExtension($listItem.Tag)]
        if (!$launchCount) { $launchCount = '0' }
        $listItem.SubItems.Add($launchCount) | Out-Null # $script:colPlayCount

        $listView.Items.Add($listItem) | Out-Null
    }

    $index = 0

    if ($listView.Items.Count -ne 0) {
        if ($selectedItemText) {
            $found = $listView.FindItemWithText($selectedItemText)
            if ($found) {
                $index = $found.Index
            }
        }
    }

    $listView.SelectedItems.Clear()
    $listView.Items[$index].Selected = $true
    $listView.Items[$index].Focused = $true
    $listView.Items[$index].EnsureVisible()
}

# =============================================================================
# Invoke-HelpForm

function Invoke-HelpForm {
    $helpForm = New-Object -TypeName 'Windows.Forms.Form'
    $helpForm.Text = 'Keyboard Mappings'
    $helpForm.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList @(350, 500)
    $helpForm.StartPosition = 'CenterScreen'

    $textBox = New-Object -TypeName 'Windows.Forms.TextBox'
    $textBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $textBox.Font = New-Object -TypeName 'Drawing.Font' -ArgumentList @('Consolas', 10, [Drawing.FontStyle]::Regular)
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = 'Vertical'
    $textBox.Text = @"
Visual Pinball
--------------
Left Shift	Left Flipper
Right Shift	Right Flipper
Left Ctrl	Left Magna Save
?	Right Magna Save
Enter	Launch Ball
1	Start Button
5	Insert Coin 1
4	Insert Coin 2
Q	Exit Game
T	Mechanical Tilt
Z	Nudge from Left
/	Nudge from Right
Space	Nudge forward

Visual PinMAME
--------------
F1	Game options...
F2	Keyboard settings...
F3	Reset emulation
F4	Toggle Display lock
F5	Toggle Display size
F6	Show DIP Switch / Option Menu
B	Add / Remove Ball From Table
T	Bang Back

Sega/Stern Whitestar keys:
3	Insert Coin #1
4	Insert Coin #2
5	Insert Coin #3
7	Black
8	Green
9	Red
Home	Slam Tilt

Volume Control
--------------
End: Open/close the coin door.
7, 8, 9, 0: Adjust the ROM volume.
^: Enter the menu system.
~: Exit the menu system.
7: Enter the menu system.
Shift: Adjust the volume percentage.
Arrow keys: Adjust the volume.
F3: Restart the table to show DMD.
Alt-tab: Switch to the DMD.
~: Close the DMD.
"@

    $textBox.Add_KeyDown({
            param($source, $e)
            if ($_.KeyCode -eq [Windows.Forms.Keys]::Escape) {
                $source.Parent.Close()
            }
        })

    $helpForm.Controls.Add($textBox)

    $OKButton = New-Object -TypeName 'Windows.Forms.Button'
    $OKButton.Location = New-Object -TypeName 'Drawing.Point' -ArgumentList @(75, 120)
    $OKButton.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList @(75, 23)
    $OKButton.Text = 'OK'
    $OKButton.DialogResult = [Windows.Forms.DialogResult]::OK
    $helpForm.AcceptButton = $OKButton
    $helpForm.Controls.Add($OKButton)

    $helpForm.ShowDialog() | Out-Null
}

# =============================================================================
# Invoke-MainWindow

function Invoke-MainWindow {
    param (
        [Parameter(Mandatory)][string]$TablePath
    )

    Write-Verbose "Using table path $TablePath"

    $script:listViewSort = @{
        Column     = 0
        Descending = $false
    }

    Add-Type -AssemblyName 'System.Windows.Forms'
    Add-Type -AssemblyName 'PresentationFramework' # MessageBox

    $form = New-Object -TypeName 'Windows.Forms.Form'

    ### LIST PANEL

    $panelListView = New-Object -TypeName 'Windows.Forms.Panel'
    $panelListView.Dock = [Windows.Forms.DockStyle]::Top
    $panelListView.Height = 439

    $listView = New-Object -TypeName 'Windows.Forms.ListView'
    $listView.Dock = [Windows.Forms.DockStyle]::Fill
    $listView.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $listView.FullRowSelect = $true
    $listView.MultiSelect = $false
    $listView.View = [Windows.Forms.View]::Details
    $listView.Font = New-Object  System.Drawing.Font('Calibri', 12, [Drawing.FontStyle]::Regular)
    $listView.BackColor = $script:colorScheme.ListView_BackColor
    $listView.ForeColor = $script:colorScheme.ListView_ForeColor

    $listView.Columns.Add('Title', 200) | Out-Null
    $listView.Columns.Add('Manufact.', 130) | Out-Null
    $listView.Columns.Add('Year', 53) | Out-Null
    $listView.Columns.Add('Details', 130) | Out-Null
    $listView.Columns.Add('Play', 50) | Out-Null

    $panelListView.Controls.Add($listView)

    Invoke-ListRefresh -TablePath $TablePath -ListView $listView

    $listView.add_SelectedIndexChanged({
            if ($listView.SelectedItems.Count -eq 1) {
                $filename = $listView.SelectedItems.Tag

                # Update metadata.
                # Uses cache to avoid multiple lookups in puplookup table.
                $tableMeta = $script:metadataCache[$filename]
                if (-not $tableMeta) {

                    $pupkey = '{0} ({1} {2})' -f `
                        $listView.SelectedItems.Text, `
                        $listView.SelectedItems.SubItems[$script:colManufacturer].Text, `
                        $listView.SelectedItems.SubItems[$script:colYear].Text

                    $name = $pupkey

                    if ($script:puplookup.ContainsKey($pupkey)) {
                        $details = '{0}/10; {1} player; {2}; {3}' -f
                        $script:puplookup[$pupkey].Rating,
                        $script:puplookup[$pupkey].NumPlayers,
                        $script:puplookup[$pupkey].Type,
                        $script:puplookup[$pupkey].Theme
                    }
                    else {
                        $details = $listView.SelectedItems.SubItems[$script:colDetails].Text
                    }

                    $tableMeta = @{
                        Name    = $name
                        Details = $details
                    }

                    $script:metadataCache[$filename] = $tableMeta
                }

                $tableNameLabel.Text = $tableMeta.Name
                $tableDetailsLabel.Text = $tableMeta.Details
            }
        })

    $listView.add_ColumnClick({
            $column = $_.Column
            if ($column -ne $script:listViewSort.Column) {
                # Column change, always start with ascending sort
                $script:listViewSort.Column = $column
                $script:listViewSort.Descending = $false
            }
            else {
                $script:listViewSort.Descending = !$script:listViewSort.Descending
            }

            # https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.listviewitem?view=windowsdesktop-9.0
            # Make deep copy of Items and sort

            if ($script:listViewSort.Column -eq 1) {
                # When sorting by Manufacturer, also sort by year
                $items = $this.Items `
                | ForEach-Object { $_ } `
                | Sort-Object -Descending:$script:listViewSort.Descending  -Property `
                @{Expression = { $_.SubItems[$script:listViewSort.Column].Text } }, @{Expression = { $_.SubItems[2].Text } }
            }

            else {
                $items = $this.Items `
                | ForEach-Object { $_ } `
                | Sort-Object -Descending:$script:listViewSort.Descending -Property @{
                    Expression = { $_.SubItems[$script:listViewSort.Column].Text }
                }
            }

            $this.Items.Clear()
            $this.ShowGroups = $false
            $this.Sorting = 'none'

            $items | ForEach-Object { $this.Items.Add($_) }
        })

    $listView.add_MouseDoubleClick(
        {
            # $_ : Windows.Forms.MouseEventArgs
            $tablePath = $listView.SelectedItems.Tag

            Invoke-Game -LaunchButton $buttonLaunch -PinballExe $PinballExe -TablePath $tablePath
        }
    )

    $form.KeyPreview = $true

    $listView.Add_KeyDown({
            # $_ : Windows.Forms.KeyEventArgs
            if ($_.KeyCode -eq 'F5') {
                Write-Verbose 'F5 pressed. Refreshing.'
                Invoke-ListRefresh -TablePath $TablePath -listView $listView
                $_.Handled = $true
            }
            elseif ($_.KeyCode -eq 'F1') {
                Invoke-HelpForm
            }
            elseif ($_.KeyCode -eq 'F2') {
                # Open IPDB page for selected table
                # e.g. "24 (Stern 2009)"
                $pupkey = '{0} ({1} {2})' -f `
                    $listView.SelectedItems.Text, `
                    $listView.SelectedItems.SubItems[1].Text, `
                    $listView.SelectedItems.SubItems[2].Text
                if ($script:puplookup.ContainsKey($pupkey)) {
                    Write-Verbose "F2 pressed. Showing help for '$pupkey'"
                    $IPDBNum = $script:puplookup[$pupkey].IPDBNum
                    Start-Process -FilePath "https://www.ipdb.org/machine.cgi?id=$IPDBNum"
                }
                else {
                    Write-Verbose "No help link available for '$name'"
                }
            }
        })

    $listView.Add_KeyUp({
            if ($_.Control -and $_.KeyCode -eq 'C') {
                Write-Verbose 'Ctrl-C pressed. Copying.'

                # TODO: Create global defines for column names / indices
                #   text = table, 1 = manuf, 2 = year, 3 = details, 4 = play
                [PSCustomObject]@{
                    Title        = $listView.SelectedItems.Text
                    Manufacturer = $listView.SelectedItems.SubItems[1].Text
                    Year         = $listView.SelectedItems.SubItems[2].Text
                    Details      = $listView.SelectedItems.SubItems[3].Text
                    PlayCount    = $listView.SelectedItems.SubItems[4].Text
                } | ConvertTo-Json | Set-Clipboard

                $_.Handled = $true
            }
        }
    )

    ### STATUS PANEL

    $panelStatus = New-Object -TypeName 'Windows.Forms.Panel'
    $panelStatus.Dock = [Windows.Forms.DockStyle]::Bottom
    $panelStatus.BackColor = $script:colorScheme.PanelStatus_BackColor
    $panelStatus.ForeColor = $script:colorScheme.PanelStatus_ForeColor

    $tableNameLabel = New-Object -TypeName 'Windows.Forms.Label'
    # $tableNameLabel.LinkColor = $script:colorScheme.PanelStatus_ForeColor
    $tableNameLabel.Text = ''
    $tableNameLabel.Font = New-Object  System.Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
    $tableNameLabel.Left = 5
    $tableNameLabel.Top = 4
    $tableNameLabel.Width = 440
    # $tableNameLabel.Height = 20
    $tableNameLabel.AutoSize = $false
    $tableNameLabel.AutoEllipsis = $false
    $panelStatus.Controls.Add($tableNameLabel)

    $tableDetailsLabel = New-Object -TypeName 'Windows.Forms.Label'
    $tableDetailsLabel.Text = ''
    $tableDetailsLabel.Left = 7
    $tableDetailsLabel.Top = 37
    $tableDetailsLabel.Height = 20
    $tableDetailsLabel.Width = 400
    $tableDetailsLabel.AutoSize = $false
    $tableDetailsLabel.AutoEllipsis = $true
    $panelStatus.Controls.Add($tableDetailsLabel)

    $progressBar = New-Object -TypeName 'Windows.Forms.ProgressBar'
    $progressBar.Top = 70
    $progressBar.Left = 10
    $progressBar.Width = 561
    $progressBar.Height = 20
    $progressBar.Minimum = 0
    $progressBar.Maximum = 9
    $progressBar.Value = 0
    $progressBar.BackColor = $script:colorScheme.ProgressBar_BackColor
    $progressBar.ForeColor = $script:colorScheme.ProgressBar_ForeColor
    $progressBar.Style = [Windows.Forms.ProgressBarStyle]::Continuous

    $panelStatus.Controls.Add($progressBar)

    $buttonLaunch = New-Object -TypeName 'Windows.Forms.Button'
    $buttonLaunch.Location = New-Object -TypeName 'Drawing.Size' -ArgumentList 453, 15
    $buttonLaunch.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList 118, 40
    $buttonLaunch.Text = 'Launch'

    $buttonLaunch.BackColor = $script:colorScheme.ButtonLaunch_BackColor
    $buttonLaunch.ForeColor = $script:colorScheme.ButtonLaunch_ForeColor
    $buttonLaunch.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $buttonLaunch.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(61, 142, 167)
    $buttonLaunch.FlatAppearance.BorderSize = 1;
    $panelStatus.Controls.Add($buttonLaunch)

    $buttonLaunch.Add_Click(
        {
            # $tablePath = Join-Path $TablePath $listView.SelectedItems.Tag
            $tablePath = $listView.SelectedItems.Tag

            Invoke-Game -LaunchButton $buttonLaunch -PinballExe $PinballExe -TablePath $tablePath
            $progressBar.Value = 0

            # $form.DialogResult = [Windows.Forms.DialogResult]::OK
            # $form.Close() | Out-Null
            # $form.Dispose() | Out-Null
        }
    )

    $statusStrip = New-Object -TypeName 'Windows.Forms.StatusStrip'
    $statusLabel = New-Object -TypeName 'Windows.Forms.ToolStripStatusLabel'
    $statusLabel.Text = 'F1: Keyboard help | F2: IPDB | F5: Refresh | Ctrl-C: Copy Info'
    $statusLabel.Spring = $true  # Makes it expand to fill space
    $statusStrip.Items.Add($statusLabel) | Out-Null

    ### FORM MAIN

    $form.Controls.Add($panelStatus)
    $form.Controls.Add($panelListView)
    $form.Controls.Add($statusStrip)

    $form.Add_Activated({ $listView.Select() })

    $form.Text = ('VPX Launcher v{0}' -f $script:launcherVersion)
    $form.Width = 600
    $form.Height = 600
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.AcceptButton = $buttonLaunch
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $form.ShowDialog()
}

#  ___             _     _  _ _    _                ___       _
# | _ \___ __ _ __| |___| || (_)__| |_ ___ _ _ _  _|   \ __ _| |_
# |   / -_) _` / _` |___| __ | (_-<  _/ _ \ '_| || | |) / _` |  _|
# |_|_\___\__,_\__,_|   |_||_|_/__/\__\___/_|  \_, |___/\__,_|\__|
#                                              |__/

function Read-HistoryDat {
    param (
        [Parameter(Mandatory)][string]$DatabasePath
    )

    $roms = $null
    $readingBio = $false
    [string[]]$bio = $null

    foreach ($line in (Get-Content -ErrorAction SilentlyContinue -LiteralPath $DatabasePath)) {
        if ($line.Length -ge 6 -and $line.Substring(0, 6) -eq '$info=') {
            $roms = $line.Substring(6).TrimEnd(',') -split ','
        }
        elseif ($line.Length -ge 4 -and $line.Substring(0, 4) -eq '$bio') {
            $bio = $null
            $readingBio = $true
        }
        elseif ($line.Length -ge 4 -and $line.SubString(0, 4) -eq '$end') {
            foreach ($rom in $roms) {
                [PSCustomObject]@{
                    ROM = $rom
                    Bio = $bio
                }
            }
            $readingBio = $false
            $bio = $null
        }
        elseif ($readingBio) {
            $bio += $line
        }
    }
}

# =============================================================================
# ConvertTo-AppendedArticle

function ConvertTo-AppendedArticle {
    param ([Parameter(Mandatory)][string]$String)

    'the', 'a', 'an' | ForEach-Object {
        if ($String -like "$_ *") {
            '{0}, {1}' -f $String.SubString($_.Length + 1), $String.SubString(0, $_.Length)
            return
        }
    }

    $String
}

# =============================================================================
# Read-VpxFileMetadata

function Read-VpxFileMetadata {
    param (
        [string[]]$VpxFiles
    )

    if ($VpxFiles.Count -eq 0) {
        return @()
    }

    $data = foreach ($vpxFile in $VpxFiles) {
        Write-Verbose "Parsing filename: $vpxFile"
        $baseName = [IO.Path]::GetFileNameWithoutExtension($vpxFile)

        # Use regex to try to guess table, manufacturer and year from filename.
        if ($baseName -match '(.+)[ _]?\((.+)(\d{4})\)\s*(.*)') {
            [PSCustomObject]@{
                FileName     = $vpxFile
                Table        = ConvertTo-AppendedArticle -String $matches[1].Trim()
                Manufacturer = $matches[2].Trim()
                Year         = $matches[3].Trim()
                Details      = $matches[4].Trim()
            }
        }
        else {
            [PSCustomObject]@{
                FileName     = $vpxFile
                Table        = $baseName
                Manufacturer = ''
                Year         = ''
                Details      = ''
            }
            Write-Warning ('Unable to parse filename "{0}"' -f $baseName)
        }
    }

    # Note: Not using -Unique so that each folder can have .VPX variants.
    $data.GetEnumerator() | Sort-Object Table
}

#  __  __      _
# |  \/  |__ _(_)_ _
# | |\/| / _` | | ' \
# |_|  |_\__,_|_|_||_|
#

$win32 = Add-Type -Namespace Win32  -MemberDefinition @'
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr FindWindow(string className, string windowName);

    [DllImport("kernel32.dll")]
    public static extern uint GetLastError();
'@ -Name 'Funcs' -PassThru


# Note: can't just search for class name. Window title must be specified.
if ($win32::FindWindow('VPinball', 'Visual Pinball') -ne 0) {
    Write-Warning 'Visual Pinball should be closed before running this launcher.'
    return
}


# Verify paths.
Get-Item -ErrorAction Stop -LiteralPath $PinballExe | Out-Null
Get-Item -ErrorAction Stop -LiteralPath $TablePath | Out-Null

if ($Display -ne -1) {
    # Change display in INI file.
    $vpxIni = Resolve-Path -LiteralPath "$env:AppData\vpinballx\VPinballX.ini"
    $iniData = Get-Content -LiteralPath $vpxIni -ErrorAction Stop
    $iniData -replace 'Display = \d+', ('Display = {0}' -f $Display) | Out-File -LiteralPath $vpxIni -Encoding ascii
}


$cfgPath = Join-Path -Path $env:LocalAppData -ChildPath 'vpx_launcher.json'

# Read in configuration
Write-Verbose "Reading config from $cfgPath"
if (Test-Path -LiteralPath $cfgPath -PathType Leaf) {
    $cfg = Get-Content $cfgPath | ConvertFrom-Json
    # Convert JSON to hash
    foreach ($p in $cfg.LaunchCount.PSObject.Properties) { $script:launchCount[$p.Name] = $p.Value }
}

# TODO: Display VPinMAME ROM history in a text window.
# File is typically placed in "Visual Pinball\VPinMAME\history.dat"
# $vpmRegistry = Get-ItemProperty -ErrorAction SilentlyContinue -LiteralPath 'HKCU:\Software\Freeware\Visual PinMame\globals'
# $historyDat = $vpmRegistry.history_file
# $history = Read-HistoryDat -DatabasePath $historyDat
# Write-Host -ForegroundColor Red "'$($found.Table)' Bio:"
# ($history | Where-Object ROM -eq $found.ROM).Bio | ForEach-Object { Write-Host -ForegroundColor DarkCyan $_ }

Invoke-MainWindow -TablePath $TablePath | Out-Null

# Write out configuration
Write-Verbose "Writing config to $cfgPath"
@{
    LaunchCount = $script:launchCount
} | ConvertTo-Json | Out-File $cfgPath
