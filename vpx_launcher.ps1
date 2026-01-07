[CmdletBinding()]
Param(
    # Location to the VPinball EXE
    [string]$PinballExe = (Resolve-Path 'VPinballX64.exe'),
    # Folder containing VPX tables
    [string]$TablePath = (Resolve-Path 'Tables'),
    # Zero-based display number to use. Find numbers in Settings > System > Display
    [int]$Display = -1
)

$script:launcherVersion = '1.7.7'

$script:colorScheme = @{
    # "CGA" Color Scheme
    ListView_BackColor     = [Drawing.Color]::FromArgb(0, 0, 0) # Black
    ListView_ForeColor     = [Drawing.Color]::FromArgb(255, 255, 255) # White
    PanelStatus_BackColor  = [Drawing.Color]::FromArgb(0, 0, 170) # Dark Blue
    PanelStatus_ForeColor  = [Drawing.Color]::FromArgb(255, 255, 85) # Light Yellow
    ProgressBar_BackColor  = [Drawing.Color]::FromArgb(85, 85, 85) # Dark Gray
    ProgressBar_ForeColor  = [Drawing.Color]::FromArgb(255, 255, 85) # Light Yellow
    ButtonLaunch_BackColor = [Drawing.Color]::FromArgb(170, 170, 170) # Medium Gray
    ButtonLaunch_ForeColor = [Drawing.Color]::FromArgb(0, 0, 0) # Black
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
    Param([string]$Path = ".\puplookup.csv")
    '$script:puplookup = @{'
    # GameFileName, GameNAme, Manufact, GameYear can be imferred
    foreach ($e in (Import-Csv $Path | Sort-Object -Unique GameName)) {
        '  "{0}" =  @{{ IPDBNum = {1}; Players = {2}; Type = ''{3}''; Theme = ''{4}'' }}' -f `
        ($e.GameName -replace '''', ''''''), [int]$e.IPDBNum, [int]$e.NumPlayers, $e.GameType, ($e.GameTheme -replace '''', '''''')
    }
    '}'
}

$script:puplookup = @{
    "!WOW! (Mills Novelty Company 1932)"                                                         = @{ IPDBNum = 2819; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "''300'' (Gottlieb 1975)"                                                                    = @{ IPDBNum = 2539; Players = 4; Type = 'EM'; Theme = 'Sports, Bowling' }
    "''Roid Belt Racers (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "1-2-3 (Automaticos 1973)"                                                                   = @{ IPDBNum = 5247; Players = 1; Type = 'EM'; Theme = 'TV Show, Game Show' }
    "12 Days of Christmas, The (Original 2016)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Christmas, Kids' }
    "2 in 1 (Bally 1964)"                                                                        = @{ IPDBNum = 2698; Players = 2; Type = 'EM'; Theme = 'Cards' }
    "2001 - A Space Odyssey (Original 2025)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "2001 (Gottlieb 1971)"                                                                       = @{ IPDBNum = 2697; Players = 1; Type = 'EM'; Theme = 'Fantasy' }
    "24 (Stern 2009)"                                                                            = @{ IPDBNum = 5419; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Crime' }
    "250 cc (Inder 1992)"                                                                        = @{ IPDBNum = 4089; Players = 4; Type = 'SS'; Theme = 'Sports, Motorcycle Racing' }
    "3-In-Line (Bally 1963)"                                                                     = @{ IPDBNum = 2549; Players = 4; Type = 'EM'; Theme = 'Majorettes' }
    "301 Bullseye (Grand Products 1986)"                                                         = @{ IPDBNum = 403; Players = 4; Type = 'SS'; Theme = 'Sports, Darts' }
    "4 Aces (Williams 1970)"                                                                     = @{ IPDBNum = 928; Players = 2; Type = 'EM'; Theme = 'Cards, Gambling' }
    "4 Queens (Bally 1970)"                                                                      = @{ IPDBNum = 936; Players = 1; Type = 'EM'; Theme = 'Cards, Happiness' }
    "4 Roses (Williams 1962)"                                                                    = @{ IPDBNum = 938; Players = 1; Type = 'EM'; Theme = 'Pageantry' }
    "4 Square (Gottlieb 1971)"                                                                   = @{ IPDBNum = 940; Players = 1; Type = 'EM'; Theme = 'Dancing, Happiness, Music, Psychedelic' }
    "4X4 (Atari 1983)"                                                                           = @{ IPDBNum = 3111; Players = 4; Type = 'SS'; Theme = 'Cars' }
    "8 Ball (Williams 1966)"                                                                     = @{ IPDBNum = 764; Players = 2; Type = 'EM'; Theme = 'Billiards' }
    "A Charlie Brown Christmas (Original 2023)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation, Comics, Christmas, Kids' }
    "A Christmas Carol Pinball (Original 2020)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Christmas' }
    "A Real American Hero - Operation P.I.N.B.A.L.L. - Reduced Resource Edition (Original 2017)" = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Toy Franchise, Kids' }
    "A Real American Hero - Operation P.I.N.B.A.L.L. (Original 2017)"                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Toy Franchise, Kids' }
    "A-Go-Go (Williams 1966)"                                                                    = @{ IPDBNum = 27; Players = 4; Type = 'EM'; Theme = 'Happiness, Dancing' }
    "A-ha (Original 2025)"                                                                       = @{ IPDBNum = 0; Players = 4; Type = ''; Theme = 'Synth Pop, Music' }
    "A-Team, The (Original 2023)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Action' }
    "Aaron Spelling (Data East 1992)"                                                            = @{ IPDBNum = 4339; Players = 4; Type = 'SS'; Theme = 'TV Show, Celebrities' }
    "ABBA (Original 2020)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Abra Ca Dabra (Gottlieb 1975)"                                                              = @{ IPDBNum = 2; Players = 1; Type = 'EM'; Theme = 'Fantasy, Wizards, Magic' }
    "AC/DC (Let There Be Rock Limited Edition) (Stern 2012)"                                     = @{ IPDBNum = 5776; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC (LUCI Premium) (Stern 2013)"                                                          = @{ IPDBNum = 6060; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC (LUCI Vault Edition) (Stern 2018)"                                                    = @{ IPDBNum = 6502; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC (Original 2012)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "AC/DC (Premium) (Stern 2012)"                                                               = @{ IPDBNum = 5775; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC (Pro Vault Edition) (Stern 2017)"                                                     = @{ IPDBNum = 6439; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC (Pro) (Stern 2012)"                                                                   = @{ IPDBNum = 5767; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC Back In Black (Limited Edition) (Stern 2012)"                                         = @{ IPDBNum = 5777; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "AC/DC Power Up (Original 2022)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Accept (Original 2019)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Ace High (Gottlieb 1957)"                                                                   = @{ IPDBNum = 7; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Ace of Speed (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Auto Racing' }
    "Ace Ventura - Pet Detective (Original 2019)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Comedy' }
    "Aces & Kings (Williams 1970)"                                                               = @{ IPDBNum = 11; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Aces High (Bally 1965)"                                                                     = @{ IPDBNum = 9; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling, Poker, Riverboat' }
    "Addams Family, The - B&W Edition (Bally 1992)"                                              = @{ IPDBNum = 20; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie' }
    "Addams Family, The (Bally 1992)"                                                            = @{ IPDBNum = 20; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie' }
    "Adventure (Sega 1979)"                                                                      = @{ IPDBNum = 5544; Players = 2; Type = 'SS'; Theme = 'Adventure, Boats, Recreation, Sailing, Water' }
    "Adventure Time - Rainy Day Daydream (Original 2022)"                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Adventures of Rocky and Bullwinkle and Friends (Data East 1993)"                            = @{ IPDBNum = 23; Players = 4; Type = 'SS'; Theme = 'Cartoon, Kids, TV Show, Licensed Theme' }
    "Adventures of TinTin, The (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Animation, Kids' }
    "Aerobatics (Zaccaria 1977)"                                                                 = @{ IPDBNum = 24; Players = 1; Type = 'EM'; Theme = 'Aviation' }
    "Aerosmith (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Aerosmith (Pro) (Stern 2017)"                                                               = @{ IPDBNum = 6370; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Agents 777 (Game Plan 1984)"                                                                = @{ IPDBNum = 26; Players = 4; Type = 'SS'; Theme = 'Cartoon, Crime' }
    "AIQ (Original 2022)"                                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Fantasy, Superheroes' }
    "Air Aces (Bally 1975)"                                                                      = @{ IPDBNum = 28; Players = 4; Type = 'EM'; Theme = 'Adventure, Aviation, Combat' }
    "Airborne (Capcom 1996)"                                                                     = @{ IPDBNum = 3783; Players = 4; Type = 'SS'; Theme = 'Aviation' }
    "Airborne (J. Esteban 1979)"                                                                 = @{ IPDBNum = 5133; Players = 4; Type = 'EM'; Theme = 'Aviation' }
    "Airborne Avenger (Atari 1977)"                                                              = @{ IPDBNum = 33; Players = 4; Type = 'SS'; Theme = 'Adventure, Combat, Aviation' }
    "Airport (Gottlieb 1969)"                                                                    = @{ IPDBNum = 35; Players = 2; Type = 'EM'; Theme = 'Travel' }
    "Airwolf (Original 2020)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Aviation' }
    "Akira (Original 2021)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Movie' }
    "Al Capone (LTD do Brasil 1984)"                                                             = @{ IPDBNum = 5176; Players = 4; Type = 'SS'; Theme = 'American History, Cards, Gambling, Crime, Mobsters' }
    "Al''s Garage Band Goes on a World Tour (Alvin G. 1992)"                                     = @{ IPDBNum = 3513; Players = 4; Type = 'SS'; Theme = 'Music, Singing' }
    "Aladdin''s Castle (Bally 1976)"                                                             = @{ IPDBNum = 40; Players = 2; Type = 'EM'; Theme = 'Fantasy, Mythology' }
    "Alaska (Interflip 1978)"                                                                    = @{ IPDBNum = 3888; Players = 4; Type = 'SS'; Theme = 'American Places' }
    "Albator - The Movie (Original 2022)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Kids' }
    "Albator 78 (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Kids' }
    "Alcatrazz (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music, Heavy Metal' }
    "Alfred Hitchcock''s Psycho (Original 2019)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie' }
    "Algar (Williams 1980)"                                                                      = @{ IPDBNum = 42; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Ali (Stern 1980)"                                                                           = @{ IPDBNum = 43; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing, Licensed Theme' }
    "Alice Cooper''s Nightmare Castle (Original 2019)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Alice in Chains Pinball (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Alice in Wonderland (Gottlieb 1948)"                                                        = @{ IPDBNum = 47; Players = 1; Type = 'EM'; Theme = 'Fictional Characters' }
    "Alien (Original 2019)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Aliens, Movie' }
    "Alien 2 (Original 2023)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction, Horror' }
    "Alien Covenant (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Science Fiction, Movie' }
    "Alien Nostromo - Ultimate Edition (Original 2022)"                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Science Fiction, Movie' }
    "Alien Nostromo 2 (Original 2024)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Science Fiction, Movie' }
    "Alien Poker (Williams 1980)"                                                                = @{ IPDBNum = 48; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Outer Space, Cards, Gambling' }
    "Alien Resurrection (Original 2019)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Science Fiction, Movie' }
    "Alien Star (Gottlieb 1984)"                                                                 = @{ IPDBNum = 49; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Alien Trilogy (Original 2019)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Science Fiction, Movie' }
    "Alien Warrior (LTD do Brasil 1982)"                                                         = @{ IPDBNum = 5882; Players = 4; Type = 'SS'; Theme = 'Aliens, Fantasy, Outer Space' }
    "Aliens (Original 2020)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Science Fiction, Movie' }
    "Aliens from Outer Space (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Aliens, Science Fiction' }
    "Alive (Brunswick 1978)"                                                                     = @{ IPDBNum = 50; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Alley Cats (Williams 1985)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling' }
    "Aloha (Gottlieb 1961)"                                                                      = @{ IPDBNum = 62; Players = 2; Type = 'EM'; Theme = 'American Places, Hawaii' }
    "Alvin and the Chipmunks (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation' }
    "Amazing Dr. Nim, The (E.S.R. Inc 1965)"                                                     = @{ IPDBNum = 0; Players = 2; Type = 'PM'; Theme = 'Board Games' }
    "Amazing Spider-Man, The - Sinister Six Edition (Gottlieb 1980)"                             = @{ IPDBNum = 2285; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Superheroes' }
    "Amazing Spider-Man, The (Gottlieb 1980)"                                                    = @{ IPDBNum = 2285; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Superheroes' }
    "Amazon (LTD do Brasil 1979)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Jungle, Wildlife' }
    "Amazon Hunt (Gottlieb 1983)"                                                                = @{ IPDBNum = 66; Players = 4; Type = 'SS'; Theme = 'Hunting, Jungle' }
    "America 1492 (Juegos Populares 1986)"                                                       = @{ IPDBNum = 5013; Players = 4; Type = 'SS'; Theme = 'Historical' }
    "America''s Most Haunted (Spooky Pinball 2014)"                                              = @{ IPDBNum = 6161; Players = 4; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "American Country (Original 2024)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "American Graffiti (Original 2024)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music, Movie, Rock n roll' }
    "Amigo (Bally 1974)"                                                                         = @{ IPDBNum = 71; Players = 4; Type = 'EM'; Theme = 'Dancing, Happiness, Music, Singing, World Culture' }
    "Amy Winehouse (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Andromeda - Tokyo 2074 Edition (Game Plan 1985)"                                            = @{ IPDBNum = 73; Players = 4; Type = 'SS'; Theme = 'Fantasy, Women' }
    "Andromeda (Game Plan 1985)"                                                                 = @{ IPDBNum = 73; Players = 4; Type = 'SS'; Theme = 'Fantasy, Women' }
    "Animal (Original 2017)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Animal Crossing Pinball (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Annabelle (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror, Supernatural' }
    "Antar (Playmatic 1979)"                                                                     = @{ IPDBNum = 3646; Players = 4; Type = 'SS'; Theme = 'Dragons, Fantasy' }
    "Antworld (Original 2015)"                                                                   = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Wildlife' }
    "Apache (Playmatic 1975)"                                                                    = @{ IPDBNum = 4483; Players = 1; Type = 'EM'; Theme = 'Crime, Women, Adult' }
    "Apache! (Taito do Brasil 1978)"                                                             = @{ IPDBNum = 4660; Players = 4; Type = 'EM'; Theme = 'American West, Native Americans, Warriors' }
    "Apollo (Williams 1967)"                                                                     = @{ IPDBNum = 77; Players = 1; Type = 'EM'; Theme = 'Space Exploration' }
    "Apollo 13 (Sega 1995)"                                                                      = @{ IPDBNum = 3592; Players = 6; Type = 'SS'; Theme = 'Outer Space, Movie, Astronauts, Licensed Theme' }
    "Aqualand (Juegos Populares 1986)"                                                           = @{ IPDBNum = 3935; Players = 4; Type = 'SS'; Theme = 'Amusement Park, Aquatic' }
    "Aquaman (Original 2024)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Superheroes' }
    "Aquarius (Gottlieb 1970)"                                                                   = @{ IPDBNum = 79; Players = 1; Type = 'EM'; Theme = 'Astrology' }
    "Arena (Gottlieb 1987)"                                                                      = @{ IPDBNum = 82; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Argosy (Williams 1977)"                                                                     = @{ IPDBNum = 84; Players = 4; Type = 'EM'; Theme = 'Boats, Nautical, Ships, Aquatic' }
    "Aristocrat (Williams 1979)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling, Flipperless' }
    "Arizona (LTD do Brasil 1977)"                                                               = @{ IPDBNum = 5890; Players = 2; Type = 'SS'; Theme = 'American West' }
    "Army of the Dead (Original 2021)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Horror, Movie, Supernatural' }
    "Aspen (Brunswick 1979)"                                                                     = @{ IPDBNum = 3660; Players = 4; Type = 'SS'; Theme = 'Sports, Skiing' }
    "Asterix the Twelve Tasks (Original 2022)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Asteroid Annie and the Aliens (Gottlieb 1980)"                                              = @{ IPDBNum = 98; Players = 1; Type = 'SS'; Theme = 'Science Fiction, Outer Space, Cards, Gambling, Aliens' }
    "Asteroids (Original 2016)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Astral Defender (Original 2018)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Outer Space' }
    "Astro (Gottlieb 1971)"                                                                      = @{ IPDBNum = 99; Players = 1; Type = 'EM'; Theme = 'Outer Space' }
    "Astronaut (Chicago Coin 1969)"                                                              = @{ IPDBNum = 101; Players = 2; Type = 'EM'; Theme = 'Astronauts, Outer Space' }
    "Atari 2600 (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Game Console' }
    "Atari Centipede Pinball - Color Balls Edition (Original 2020)"                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Atari Centipede Pinball (Original 2020)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Atarians, The (Atari 1976)"                                                                 = @{ IPDBNum = 102; Players = 0; Type = 'SS'; Theme = 'Adventure' }
    "Atlantis (Bally 1989)"                                                                      = @{ IPDBNum = 106; Players = 4; Type = 'SS'; Theme = 'Mythology, Aquatic' }
    "Atlantis (Gottlieb 1975)"                                                                   = @{ IPDBNum = 105; Players = 1; Type = 'EM'; Theme = 'Fantasy, Mythology' }
    "Atlantis (LTD do Brasil 1978)"                                                              = @{ IPDBNum = 6712; Players = 2; Type = 'SS'; Theme = 'Fantasy' }
    "Atleta (Inder 1991)"                                                                        = @{ IPDBNum = 4095; Players = 4; Type = 'SS'; Theme = 'Sports, Olympic Games' }
    "Attack & Revenge from Mars (Original 2015)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Aliens, Martians, Science Fiction' }
    "Attack from Mars (Bally 1995)"                                                              = @{ IPDBNum = 3781; Players = 4; Type = 'SS'; Theme = 'Aliens, Martians, Fantasy' }
    "Attack of the Killer Tomatoes (Original 2023)"                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Comedy' }
    "Attack on Titan (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Attila the Hun (Game Plan 1984)"                                                            = @{ IPDBNum = 109; Players = 4; Type = 'SS'; Theme = 'Historical' }
    "Austin Powers (Stern 2001)"                                                                 = @{ IPDBNum = 4504; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie' }
    "Avatar - The Last Airbender (Original 2024)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Kids, Adventure, TV Show, Animation, Action' }
    "Avenged Sevenfold (Original 2022)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music, Heavy Metal' }
    "Avengers - TV Series, The (Original 2023)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Spies, Action, Comedy' }
    "Avengers (Pro), The (Stern 2012)"                                                           = @{ IPDBNum = 5938; Players = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes, Movie' }
    "Aztec - High-Tap Edition (Williams 1976)"                                                   = @{ IPDBNum = 119; Players = 4; Type = 'EM'; Theme = 'Historical, World Places' }
    "Aztec (Williams 1976)"                                                                      = @{ IPDBNum = 119; Players = 4; Type = 'EM'; Theme = 'Historical, World Places' }
    "B.B. King (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Blues' }
    "Baby Leland (Stoner 1933)"                                                                  = @{ IPDBNum = 123; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Baby Pac-Man (Bally 1982)"                                                                  = @{ IPDBNum = 125; Players = 2; Type = 'SS'; Theme = 'Video Game' }
    "Baby Shark (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Babylon 5 (Original 2022)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction' }
    "Back to the Future (Data East 1990)"                                                        = @{ IPDBNum = 126; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Time Travel, Movie' }
    "Back to the Future Trilogy (Original 2022)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Time Travel, Movie' }
    "Backstreet Boys (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Bad (Original 2022)"                                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Bad Cats (Williams 1989)"                                                                   = @{ IPDBNum = 127; Players = 4; Type = 'SS'; Theme = 'Feline Mischief' }
    "Bad Girls - Alternate Edition (Gottlieb 1988)"                                              = @{ IPDBNum = 128; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Bad Girls - Tooned-Up Version (Gottlieb 1988)"                                              = @{ IPDBNum = 128; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Bad Girls (Gottlieb 1988)"                                                                  = @{ IPDBNum = 128; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Bad Lieutenant (Original 2020)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Celebrities, Movie' }
    "Bad Santa 2 Pinball XL (Original 2017)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas' }
    "Bad Santa Pinball (Original 2017)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie' }
    "Balls-A-Poppin (Bally 1956)"                                                                = @{ IPDBNum = 144; Players = 2; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Bally Game Show, The (Bally 1990)"                                                          = @{ IPDBNum = 985; Players = 4; Type = 'SS'; Theme = 'Comedy, Game Show' }
    "Bally Hoo (Bally 1969)"                                                                     = @{ IPDBNum = 151; Players = 4; Type = 'EM'; Theme = 'Circus, Carnival, Music' }
    "Ballyhoo (Bally 1932)"                                                                      = @{ IPDBNum = 4817; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Band Wagon (Bally 1965)"                                                                    = @{ IPDBNum = 163; Players = 4; Type = 'EM'; Theme = 'Circus, Carnival' }
    "Bank Shot (Gottlieb 1976)"                                                                  = @{ IPDBNum = 169; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Bank-A-Ball (Gottlieb 1965)"                                                                = @{ IPDBNum = 170; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Bank-A-Ball (J.F. Linck 1932)"                                                              = @{ IPDBNum = 6520; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Banzai Run (Williams 1988)"                                                                 = @{ IPDBNum = 175; Players = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross' }
    "Barb Wire (Gottlieb 1996)"                                                                  = @{ IPDBNum = 3795; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie, Motorcycles' }
    "Barbarella (Automaticos 1972)"                                                              = @{ IPDBNum = 5809; Players = 1; Type = 'EM'; Theme = 'Fantasy, Outer Space, Science Fiction, Movie' }
    "Barnstorming (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Aircraft' }
    "Barracora (Williams 1981)"                                                                  = @{ IPDBNum = 177; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Barry Manilow (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Music' }
    "Bart vs. the Space Mutants (Original 2017)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, TV Show' }
    "Baseball (Gottlieb 1970)"                                                                   = @{ IPDBNum = 185; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Basketball (IDSA 1986)"                                                                     = @{ IPDBNum = 5023; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball' }
    "Bat-Em (In & Outdoor 1932)"                                                                 = @{ IPDBNum = 194; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Batgirl (Original 2019)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Batman - The Animated Series (Original 2020)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation, Superheroes, Comics' }
    "Batman ''66 (Original 2018)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Batman (66 Premium) (Stern 2016)"                                                           = @{ IPDBNum = 6354; Players = 4; Type = 'SS'; Theme = 'Comics, Licensed Theme, Superheroes' }
    "Batman (Data East 1991)"                                                                    = @{ IPDBNum = 195; Players = 4; Type = 'SS'; Theme = 'Comics, Licensed Theme, Superheroes, Movie' }
    "Batman (Stern 2008)"                                                                        = @{ IPDBNum = 5307; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Superheroes, Comics' }
    "Batman Forever (Sega 1995)"                                                                 = @{ IPDBNum = 3593; Players = 6; Type = 'SS'; Theme = 'Comics, Licensed Theme, Superheroes, Movie' }
    "Batman Returns (Original 2018)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Batman Returns (Original 2019)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Superheroes' }
    "Batman, The (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Superheroes, Comics' }
    "Batter Up (Gottlieb 1970)"                                                                  = @{ IPDBNum = 197; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Battlestar Galactica (Original 2018)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, TV Show' }
    "Baywatch (Sega 1995)"                                                                       = @{ IPDBNum = 2848; Players = 6; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, TV Show' }
    "Beach Bums (Original 2018)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fictional, Beach, Surfing' }
    "Beach Goblinball (Original 2025)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Beach, Sports, Volleyball, Women' }
    "Beastie Boys (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rap, Rock' }
    "Beastmaster, The (Original 2021)"                                                           = @{ IPDBNum = 0; Players = 2; Type = 'SS'; Theme = 'Movie' }
    "Beat the Clock (Bally 1985)"                                                                = @{ IPDBNum = 212; Players = 4; Type = 'SS'; Theme = 'Sports' }
    "Beat Time - Beatles Edition (Williams 1967)"                                                = @{ IPDBNum = 213; Players = 2; Type = 'EM'; Theme = 'Happiness, Music' }
    "Beat Time (Williams 1967)"                                                                  = @{ IPDBNum = 213; Players = 2; Type = 'EM'; Theme = 'Happiness, Music' }
    "Beatles, The (Stern 2018)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Beavis and Butt-Head Pinball Stupidity (Original 2023)"                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, TV Show, Movie' }
    "Beavis and Butt-Head Pinballed (Original 2024)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, TV Show, Movie' }
    "Beetlejuice (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror, Supernatural' }
    "Beetlejuice (Original 2023)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror, Supernatural' }
    "Beisbol (Maresa 1971)"                                                                      = @{ IPDBNum = 5320; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Bell Ringer (Gottlieb 1990)"                                                                = @{ IPDBNum = 3602; Players = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross' }
    "Bella Dama (Original 2023)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Women' }
    "Ben Hur (Staal 1977)"                                                                       = @{ IPDBNum = 2855; Players = 4; Type = 'SS'; Theme = 'Fictional Characters, World Places' }
    "Berzerk (Original 2016)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Beverly Hills Cop (Original 2019)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Police' }
    "Biene Maja (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Big Bang Bar (Capcom 1996)"                                                                 = @{ IPDBNum = 4001; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Aliens' }
    "Big Ben (Williams 1975)"                                                                    = @{ IPDBNum = 232; Players = 1; Type = 'EM'; Theme = 'World Places, Landmarks' }
    "Big Brave - B&W Edition (Gottlieb 1974)"                                                    = @{ IPDBNum = 234; Players = 2; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Big Brave (Gottlieb 1974)"                                                                  = @{ IPDBNum = 234; Players = 2; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Big Brave (Maresa 1974)"                                                                    = @{ IPDBNum = 4634; Players = 2; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Big Buck Hunter Pro (Stern 2010)"                                                           = @{ IPDBNum = 5513; Players = 4; Type = 'SS'; Theme = 'Hunting, Licensed Theme' }
    "Big Casino (Gottlieb 1961)"                                                                 = @{ IPDBNum = 239; Players = 1; Type = 'EM'; Theme = 'Gambling, Cards' }
    "Big Chief (Williams 1965)"                                                                  = @{ IPDBNum = 240; Players = 4; Type = 'EM'; Theme = 'Native Americans' }
    "Big Deal (Williams 1963)"                                                                   = @{ IPDBNum = 244; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Big Deal (Williams 1977)"                                                                   = @{ IPDBNum = 245; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Big Dick - Orphaned on vpinball.com (Fabulous Fantasies 1996)"                              = @{ IPDBNum = 4539; Players = 1; Type = 'EM'; Theme = 'Adult' }
    "Big Dick (Fabulous Fantasies 1996)"                                                         = @{ IPDBNum = 4539; Players = 1; Type = 'EM'; Theme = 'Adult' }
    "Big Flush (LTD do Brasil 1983)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Cards' }
    "Big Game (Rock-ola 1935)"                                                                   = @{ IPDBNum = 248; Players = 1; Type = 'PM'; Theme = 'Sports, Hunting' }
    "Big Game (Stern 1980)"                                                                      = @{ IPDBNum = 249; Players = 4; Type = 'SS'; Theme = 'Hunting, Safari' }
    "Big Guns (Williams 1987)"                                                                   = @{ IPDBNum = 250; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Big Hit (Gottlieb 1977)"                                                                    = @{ IPDBNum = 253; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Big Horse (Maresa 1975)"                                                                    = @{ IPDBNum = 255; Players = 1; Type = 'EM'; Theme = 'Fantasy' }
    "Big House (Gottlieb 1989)"                                                                  = @{ IPDBNum = 256; Players = 4; Type = 'SS'; Theme = 'Crime, Police' }
    "Big Indian (Gottlieb 1974)"                                                                 = @{ IPDBNum = 257; Players = 4; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Big Injun (Gottlieb 1974)"                                                                  = @{ IPDBNum = 257; Players = 4; Type = 'EM'; Theme = 'Native Americans, American West' }
    "Big Lebowski Pinball, The - PuP-Pack Edition (Original 2016)"                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Bowling, Movie' }
    "Big Lebowski Pinball, The (Original 2016)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Bowling, Movie' }
    "Big Shot (Gottlieb 1974)"                                                                   = @{ IPDBNum = 271; Players = 2; Type = 'EM'; Theme = 'Billiards' }
    "Big Show (Bally 1974)"                                                                      = @{ IPDBNum = 275; Players = 2; Type = 'EM'; Theme = 'Circus, Carnival' }
    "Big Star (Williams 1972)"                                                                   = @{ IPDBNum = 279; Players = 1; Type = 'EM'; Theme = 'Music' }
    "Big Top (Gottlieb 1988)"                                                                    = @{ IPDBNum = 5347; Players = 4; Type = 'SS'; Theme = 'Circus, Carnival' }
    "Big Town (Playmatic 1978)"                                                                  = @{ IPDBNum = 3607; Players = 4; Type = 'SS'; Theme = 'City Skyline' }
    "Big Trouble in Little China (Original 2020)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Martial Arts' }
    "Big Trouble in Little China (Original 2022)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Action, Adventure, Comedy, Martial Arts, Supernatural' }
    "Big Valley (Bally 1970)"                                                                    = @{ IPDBNum = 289; Players = 4; Type = 'EM'; Theme = 'American West' }
    "Biker Mice from Mars (Original 2024)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids, Action, TV Show' }
    "Billy Idol (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Bird Fly (Original 2022)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Wildlife' }
    "Black & Red (Inder 1975)"                                                                   = @{ IPDBNum = 4413; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Black Belt (Bally 1986)"                                                                    = @{ IPDBNum = 303; Players = 4; Type = 'SS'; Theme = 'Martial Arts' }
    "Black Fever (Playmatic 1980)"                                                               = @{ IPDBNum = 3645; Players = 4; Type = 'SS'; Theme = 'Dancing, Music, Women' }
    "Black Gold (Williams 1975)"                                                                 = @{ IPDBNum = 306; Players = 1; Type = 'EM'; Theme = 'American History' }
    "Black Hole (Gottlieb 1981)"                                                                 = @{ IPDBNum = 307; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Black Hole (LTD do Brasil 1982)"                                                            = @{ IPDBNum = 5891; Players = 2; Type = 'SS'; Theme = 'Outer Space, Space Fantasy' }
    "Black Jack (SS) (Bally 1978)"                                                               = @{ IPDBNum = 309; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Black Knight (Williams 1980)"                                                               = @{ IPDBNum = 310; Players = 4; Type = 'SS'; Theme = 'Medieval, Knights' }
    "Black Knight 2000 (Williams 1989)"                                                          = @{ IPDBNum = 311; Players = 4; Type = 'SS'; Theme = 'Medieval, Knights' }
    "Black Knight Sword of Rage (Stern 2019)"                                                    = @{ IPDBNum = 6569; Players = 4; Type = 'SS'; Theme = 'Medieval, Knights' }
    "Black Magic 4 (Recel 1980)"                                                                 = @{ IPDBNum = 3626; Players = 4; Type = 'SS'; Theme = 'Occult, Black Magic' }
    "Black Pyramid (Bally 1984)"                                                                 = @{ IPDBNum = 312; Players = 4; Type = 'SS'; Theme = 'Adventure, Supernatural' }
    "Black Rose (Bally 1992)"                                                                    = @{ IPDBNum = 313; Players = 4; Type = 'SS'; Theme = 'Fantasy, Pirates, Fictional' }
    "Black Sabbath the ''70s (Original 2020)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Black Sheep Squadron (Astro Games 1979)"                                                    = @{ IPDBNum = 314; Players = 4; Type = 'SS'; Theme = 'Adventure, Combat' }
    "Black Tiger Pinball (Original 2022)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Black Velvet (Game Plan 1978)"                                                              = @{ IPDBNum = 315; Players = 4; Type = 'SS'; Theme = 'Licensed Theme' }
    "Blackout (Williams 1980)"                                                                   = @{ IPDBNum = 317; Players = 4; Type = 'SS'; Theme = 'Outer Space, Space Fantasy' }
    "Blackwater 100 (Bally 1988)"                                                                = @{ IPDBNum = 319; Players = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross' }
    "Blade Runner 2049 - PuP-Pack Edition (Original 2020)"                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Blade Runner 2049 (Original 2020)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Blank Table with Scoring (Original 2016)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Blaze and the Monster Machines (Original 2021)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Kids' }
    "Bleach (Original 2023)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Blink 182 (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Blizzard Of Ozz, The (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Blood Machines (Original 2022)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Bloodsport (Original 2019)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Bloodsport (Original 2023)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Martial Arts' }
    "Blue Chip (Williams 1976)"                                                                  = @{ IPDBNum = 325; Players = 1; Type = 'EM'; Theme = 'Stock Market' }
    "Blue Note (Gottlieb 1978)"                                                                  = @{ IPDBNum = 328; Players = 1; Type = 'EM'; Theme = 'Music, Singing' }
    "Blues Brothers 40th Anniversary, The (Original 2020)"                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Blues Brothers, The (Original 2020)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Movie, Blues' }
    "Bluey (Original 2021)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Cartoon, Kids' }
    "BMX - RAD Edition (Bally 1983)"                                                             = @{ IPDBNum = 335; Players = 4; Type = 'SS'; Theme = 'Sports, Bicycling' }
    "BMX - Radical Rick Edition (Bally 1983)"                                                    = @{ IPDBNum = 335; Players = 4; Type = 'SS'; Theme = 'Sports, Bicycling' }
    "BMX (Bally 1983)"                                                                           = @{ IPDBNum = 335; Players = 4; Type = 'SS'; Theme = 'Sports, Bicycling' }
    "Bob Cuspe (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = ''; Theme = 'Punk, Music' }
    "Bob Marley (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Bob Seger (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Bob''s Burgers (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Animation, Kids, Food' }
    "Bobby Orr Power Play (Bally 1978)"                                                          = @{ IPDBNum = 1858; Players = 4; Type = 'SS'; Theme = 'Sports, Hockey, Celebrities' }
    "Bon Jovi (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Bon Voyage (Bally 1974)"                                                                    = @{ IPDBNum = 343; Players = 1; Type = 'EM'; Theme = 'Aviation, Travel, Transportation' }
    "Bonanza (Original 2022)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'American West, TV Show' }
    "Bond 60th (Limited Edition) (Original 2023)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Espionage' }
    "Bond 60th (Original 2022)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Espionage' }
    "Bone Busters Inc. (Gottlieb 1989)"                                                          = @{ IPDBNum = 347; Players = 4; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Boomerang (Bally 1974)"                                                                     = @{ IPDBNum = 354; Players = 4; Type = 'EM'; Theme = 'Adventure, World Culture' }
    "Boop-A-Doop (Pace 1932)"                                                                    = @{ IPDBNum = 3653; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Border Town (Gottlieb 1940)"                                                                = @{ IPDBNum = 357; Players = 1; Type = 'EM'; Theme = 'American History, American West' }
    "Boston (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Bounty Hunter (Gottlieb 1985)"                                                              = @{ IPDBNum = 361; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Bourne Identity, The - Challenge Edition (Original 2024)"                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Espionage, Action, Movie' }
    "Bourne Identity, The - PuP-Pack Edition (Original 2024)"                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Espionage, Action, Movie' }
    "Bourne Identity, The - Treadstone Edition (Original 2024)"                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Espionage, Action, Movie' }
    "Bow and Arrow (EM) (Bally 1975)"                                                            = @{ IPDBNum = 362; Players = 4; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Bow and Arrow (SS) (Bally 1974)"                                                            = @{ IPDBNum = 4770; Players = 4; Type = 'SS'; Theme = 'American West, Native Americans' }
    "Bowie Star Man (Original 2019)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Bowling - Alle Neune (NSM 1976)"                                                            = @{ IPDBNum = 6037; Players = 1; Type = 'EM'; Theme = 'Bowling, Sports' }
    "Boxster Pinball (Original 2010)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Auto Racing' }
    "Brady Bunch, The (Original 2025)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Brainscan (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Bram Stoker''s Dracula - Blood Edition (Williams 1993)"                                     = @{ IPDBNum = 3072; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Fictional, Horror, Supernatural, Movie' }
    "Bram Stoker''s Dracula (Williams 1993)"                                                     = @{ IPDBNum = 3072; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Fictional, Horror, Supernatural, Movie' }
    "Brave Team (Inder 1985)"                                                                    = @{ IPDBNum = 4480; Players = 4; Type = 'SS'; Theme = 'Motorcycles' }
    "Bravestarr (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Animation, Cartoon, Kids' }
    "Break (Video Dens 1986)"                                                                    = @{ IPDBNum = 5569; Players = 4; Type = 'SS'; Theme = 'Dancing' }
    "Breakin (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Dancing, Movie, Musical' }
    "Breaking Bad (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Breaking Bad (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Breakshot (Capcom 1996)"                                                                    = @{ IPDBNum = 3784; Players = 4; Type = 'SS'; Theme = 'Sports, Billiards' }
    "Bristol Hills (Gottlieb 1971)"                                                              = @{ IPDBNum = 376; Players = 2; Type = 'EM'; Theme = 'Sports, Skiing, Snowmobiling' }
    "Britney Spears (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Bronco (Gottlieb 1977)"                                                                     = @{ IPDBNum = 388; Players = 4; Type = 'EM'; Theme = 'American West' }
    "Bubba the Redneck Werewolf (Original 2017)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Buccaneer (Gottlieb 1948)"                                                                  = @{ IPDBNum = 390; Players = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical' }
    "Buccaneer (Gottlieb 1976)"                                                                  = @{ IPDBNum = 391; Players = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical' }
    "Buccaneer (J. Esteban 1976)"                                                                = @{ IPDBNum = 6276; Players = 4; Type = 'EM'; Theme = 'Adventure, Pirates' }
    "Buck Rogers (Gottlieb 1980)"                                                                = @{ IPDBNum = 392; Players = 4; Type = 'SS'; Theme = 'Fantasy, Outer Space, TV Show' }
    "Buckaroo (Gottlieb 1965)"                                                                   = @{ IPDBNum = 393; Players = 1; Type = 'EM'; Theme = 'American West' }
    "Bud Spencer & Terence Hill (Original 2024)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Action, Comedy' }
    "Buffy the Vampire Slayer (Original 2022)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Supernatural' }
    "Bugs and Jokers (Original 2023)"                                                            = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Wildlife' }
    "Bugs Bunny''s Birthday Ball (Bally 1990)"                                                   = @{ IPDBNum = 396; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Cartoon, Happiness, Kids' }
    "Bumper - B&W Edition (Bill Port 1977)"                                                      = @{ IPDBNum = 6194; Players = 1; Type = 'EM'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Bumper (Bill Port 1977)"                                                                    = @{ IPDBNum = 6194; Players = 1; Type = 'EM'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Bumper Pool (Gottlieb 1969)"                                                                = @{ IPDBNum = 406; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Bunnyboard (Marble Games 1932)"                                                             = @{ IPDBNum = 407; Players = 0; Type = 'EM'; Theme = 'Flipperless' }
    "Bushido (Inder 1993)"                                                                       = @{ IPDBNum = 4481; Players = 4; Type = 'SS'; Theme = 'World Culture' }
    "Caballeros del Zodiaco (Original 2022)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Cabaret (Williams 1968)"                                                                    = @{ IPDBNum = 415; Players = 4; Type = 'EM'; Theme = 'Dancing, Happiness, Music, Nightlife, Singing' }
    "Cactus Canyon (Bally 1998)"                                                                 = @{ IPDBNum = 4445; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Cactus Canyon Continued (Original 2019)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Cactus Jack''s (Gottlieb 1991)"                                                             = @{ IPDBNum = 416; Players = 4; Type = 'SS'; Theme = 'Music, Singing, Dancing, Comedy, Country and Western' }
    "Caddie (Playmatic 1970)"                                                                    = @{ IPDBNum = 417; Players = 1; Type = 'EM'; Theme = 'Sports, Golf' }
    "Camping Trip! (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = ''; Theme = 'Music, Camping' }
    "Canada Dry (Gottlieb 1976)"                                                                 = @{ IPDBNum = 426; Players = 4; Type = 'EM'; Theme = 'Licensed Theme, Drinking' }
    "Canasta 86 (Inder 1986)"                                                                    = @{ IPDBNum = 4097; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball' }
    "Cannes (Segasa 1976)"                                                                       = @{ IPDBNum = 428; Players = 4; Type = 'EM'; Theme = 'World Places, Aquatic, Sports, Happiness, Recreation, Water Skiing, Swimming' }
    "Cannon Fodder (Original 2018)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Capersville (Bally 1966)"                                                                   = @{ IPDBNum = 431; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Capt. Card (Gottlieb 1974)"                                                                 = @{ IPDBNum = 433; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Capt. Fantastic and the Brown Dirt Cowboy (Bally 1976)"                                     = @{ IPDBNum = 438; Players = 4; Type = 'EM'; Theme = 'Celebrities, Fictional, Licensed Theme' }
    "Captain Future (Original 2022)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Science Fiction' }
    "Captain NEMO Dives Again - Steampunk Flyer Edition (Quetzal Pinball 2015)"                  = @{ IPDBNum = 6465; Players = 4; Type = 'SS'; Theme = 'Fictional Characters' }
    "Captain NEMO Dives Again (Quetzal Pinball 2015)"                                            = @{ IPDBNum = 6465; Players = 4; Type = 'SS'; Theme = 'Fictional Characters' }
    "Captain Spaulding''s Museum of Monsters and Madmen (Original 2025)"                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror, Monsters' }
    "Car Hop (Gottlieb 1991)"                                                                    = @{ IPDBNum = 3676; Players = 4; Type = 'SS'; Theme = 'Cars, Food' }
    "Carcariass Pinball Chaos (Original 2021)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Card King (Gottlieb 1971)"                                                                  = @{ IPDBNum = 445; Players = 1; Type = 'EM'; Theme = 'Playing Cards' }
    "Card Trix (Gottlieb 1970)"                                                                  = @{ IPDBNum = 446; Players = 1; Type = 'EM'; Theme = 'College Life, Happiness, Music, Cards' }
    "Card Whiz (Gottlieb 1976)"                                                                  = @{ IPDBNum = 447; Players = 2; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Carnaval no Rio (LTD do Brasil 1977)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Carnival, Circus, Clowns' }
    "Carnival Games (Original 2025)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Carnival' }
    "Carnival Queen (Bally 1958)"                                                                = @{ IPDBNum = 456; Players = 1; Type = 'EM'; Theme = 'Carnival, Happiness' }
    "Carrie Underwood (Original 2021)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Country and Western' }
    "CARtoons RC (Original 2017)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Comics, Auto Racing' }
    "Casino (Williams 1958)"                                                                     = @{ IPDBNum = 463; Players = 1; Type = 'EM'; Theme = 'Gambling' }
    "Castlevania - Symphony of the Night (Original 2022)"                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Cat Burglars (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Anime' }
    "Catacomb (Stern 1981)"                                                                      = @{ IPDBNum = 469; Players = 4; Type = 'SS'; Theme = 'Horror' }
    "Cavalcade (Stoner 1935)"                                                                    = @{ IPDBNum = 473; Players = 1; Type = 'EM'; Theme = 'Horse Racing, Flipperless' }
    "Cavaleiro Negro (Taito do Brasil 1980)"                                                     = @{ IPDBNum = 4568; Players = 4; Type = 'SS'; Theme = 'Medieval, Knights' }
    "Cavalier (Recel 1979)"                                                                      = @{ IPDBNum = 474; Players = 4; Type = 'SS'; Theme = 'Historical Characters' }
    "Caveman (Gottlieb 1982)"                                                                    = @{ IPDBNum = 475; Players = 4; Type = 'SS'; Theme = 'Historical' }
    "Cenobite (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Centaur (Bally 1981)"                                                                       = @{ IPDBNum = 476; Players = 4; Type = 'SS'; Theme = 'Fantasy, Motorcycles' }
    "Centigrade 37 (Gottlieb 1977)"                                                              = @{ IPDBNum = 480; Players = 1; Type = 'EM'; Theme = 'Fantasy, Science Fiction' }
    "Central Park (Gottlieb 1966)"                                                               = @{ IPDBNum = 481; Players = 1; Type = 'EM'; Theme = 'American Places' }
    "Cerberus (Playmatic 1983)"                                                                  = @{ IPDBNum = 3004; Players = 4; Type = 'SS'; Theme = '' }
    "Cerebral Maze, The (Original 2022)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Champ (Bally 1974)"                                                                         = @{ IPDBNum = 486; Players = 4; Type = 'EM'; Theme = 'Sports, Pinball' }
    "Champion Pub, The (Bally 1998)"                                                             = @{ IPDBNum = 4358; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing' }
    "Champions League - Libertadores narracao Brasileira (Original 2020)"                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Champions League - Season 2017 (Original 2017)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Champions League - Season 2018 (Original 2017)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Champions League - Season 2018 (St. Pauli) (Original 2018)"                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Champions League - Season 2020 (Original 2020)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Champions League - Season 2023 (Original 2023)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Champions League 2021 (Original 2020)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Chance (Playmatic 1974)"                                                                    = @{ IPDBNum = 4878; Players = 1; Type = 'EM'; Theme = 'Magic, Witchcraft' }
    "Chance (Playmatic 1978)"                                                                    = @{ IPDBNum = 491; Players = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival' }
    "Charlie''s Angels (Gottlieb 1978)"                                                          = @{ IPDBNum = 492; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show' }
    "Charlie''s Angels (Gottlieb 1979)"                                                          = @{ IPDBNum = 5007; Players = 4; Type = 'EM'; Theme = 'Licensed Theme, TV Show, Women' }
    "Check (Recel 1975)"                                                                         = @{ IPDBNum = 495; Players = 2; Type = 'EM'; Theme = 'Chess' }
    "Check Mate (Recel 1975)"                                                                    = @{ IPDBNum = 496; Players = 4; Type = 'EM'; Theme = 'Chess' }
    "Check Mate (Taito do Brasil 1977)"                                                          = @{ IPDBNum = 5491; Players = 4; Type = 'EM'; Theme = 'Board Games' }
    "Checkpoint (Data East 1991)"                                                                = @{ IPDBNum = 498; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Cheech & Chong - Road-Trip''pin (Original 2021)"                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Roap Trip, Comedy' }
    "Cheese Squad (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Cheese Squad 2 (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = '' }
    "Cheetah (Stern 1980)"                                                                       = @{ IPDBNum = 500; Players = 4; Type = 'SS'; Theme = 'Jungle, Fantasy' }
    "Chef-ball (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = '' }
    "Cherry Coke (Original 2020)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Drinking' }
    "Chicago Cubs ''Triple Play'' (Gottlieb 1985)"                                               = @{ IPDBNum = 502; Players = 4; Type = 'SS'; Theme = 'Sports, Baseball' }
    "Child''s Play (Original 2017)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Horror, Movie' }
    "Child''s Play (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Movie, Horror' }
    "Chime Speed Test Table (Original 2021)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Testing, Example' }
    "Chris Cornell (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Christmas Pinball (Original 2018)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Christmas' }
    "Christmas Vaction (Original 2019)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Comedy, Christmas' }
    "Chrono Trigger (Original 2022)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Chuck Berry (Original 2020)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Circus (Bally 1973)"                                                                        = @{ IPDBNum = 521; Players = 4; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Circus (Brunswick 1980)"                                                                    = @{ IPDBNum = 4937; Players = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival' }
    "Circus (Gottlieb 1980)"                                                                     = @{ IPDBNum = 515; Players = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival' }
    "Circus (Zaccaria 1977)"                                                                     = @{ IPDBNum = 518; Players = 4; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Cirqus Voltaire (Bally 1997)"                                                               = @{ IPDBNum = 4059; Players = 4; Type = 'SS'; Theme = 'Circus, Carnival' }
    "City Hunter (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Action, Anime, Detective' }
    "City on the Moon - Murray Leinster (Original 2024)"                                         = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction' }
    "City Ship (J. Esteban 1978)"                                                                = @{ IPDBNum = 5130; Players = 2; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "City Slicker (Bally 1987)"                                                                  = @{ IPDBNum = 527; Players = 4; Type = 'SS'; Theme = 'Crime, Mobsters, Police' }
    "Clash Pro - Audio Ammunition, The (Original 2020)"                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Singing' }
    "Clash, The (Original 2018)"                                                                 = @{ IPDBNum = 1979; Players = 4; Type = 'SS'; Theme = 'Music, Singing' }
    "Class of 1812 (Gottlieb 1991)"                                                              = @{ IPDBNum = 528; Players = 4; Type = 'SS'; Theme = 'Adventure, Supernatural' }
    "Class of 1984 (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Thriller' }
    "Cleopatra (SS) (Gottlieb 1977)"                                                             = @{ IPDBNum = 532; Players = 4; Type = 'SS'; Theme = 'Historical' }
    "Clever & Smart (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Clock of Eternal Fog (Original 2024)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Time Travel, Fantasy' }
    "Clockwork Orange (Original 2022)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Close Encounters of the Third Kind (Gottlieb 1978)"                                         = @{ IPDBNum = 536; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Science Fiction' }
    "Cloudy with a Chance of Meatballs (Original 2021)"                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation' }
    "Clown (Inder 1988)"                                                                         = @{ IPDBNum = 4093; Players = 4; Type = 'SS'; Theme = 'Circus, Carnival, Clowns' }
    "Clown (Playmatic 1971)"                                                                     = @{ IPDBNum = 5447; Players = 1; Type = 'EM'; Theme = 'Circus, Carnival, Clowns' }
    "Clue (Original 2018)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Detective, Crime, Board Games' }
    "Clutch (Original 2021)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Cobra (Nuova Bell Games 1987)"                                                              = @{ IPDBNum = 3026; Players = 4; Type = 'SS'; Theme = 'Cops and Robbers' }
    "Cobra (Original 2022)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Science Fiction' }
    "Cobra (Playbar 1987)"                                                                       = @{ IPDBNum = 4124; Players = 4; Type = 'SS'; Theme = 'Cops and Robbers' }
    "Cobretti (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Action, Movie' }
    "Coldplay Pinball (Original 2020)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "College Queens (Gottlieb 1969)"                                                             = @{ IPDBNum = 543; Players = 4; Type = 'EM'; Theme = 'Happiness, School, Women' }
    "Columbia (LTD do Brasil 1983)"                                                              = @{ IPDBNum = 5759; Players = 4; Type = 'SS'; Theme = 'Outer Space, Exploration' }
    "Combination Rotation (Gottlieb 1982)"                                                       = @{ IPDBNum = 5331; Players = 4; Type = 'SS'; Theme = '' }
    "Comet (Williams 1985)"                                                                      = @{ IPDBNum = 548; Players = 4; Type = 'SS'; Theme = 'Happiness, Amusement Park, Roller Coasters' }
    "Comic Book Guy (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Animation, Cartoon, Kids' }
    "Commando - Schwarzenegger (Original 2019)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Celebrities, Movie' }
    "Conan (Rowamet 1983)"                                                                       = @{ IPDBNum = 4580; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie' }
    "Concorde (Emagar 1975)"                                                                     = @{ IPDBNum = 6024; Players = 1; Type = 'EM'; Theme = 'Aircraft, Aviation, Historical, Travel' }
    "Congo (Williams 1995)"                                                                      = @{ IPDBNum = 3780; Players = 4; Type = 'SS'; Theme = 'Jungle, Movie, Licensed Theme' }
    "Conjuring, The (Original 2020)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Supernatural, Movie' }
    "Conjury Contraption (Original 2024)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Magic' }
    "Conquest 200 (Playmatic 1976)"                                                              = @{ IPDBNum = 557; Players = 1; Type = 'EM'; Theme = 'Historical' }
    "Contact (Williams 1978)"                                                                    = @{ IPDBNum = 558; Players = 4; Type = 'SS'; Theme = 'Aliens, Fantasy, Outer Space' }
    "Contact Master (PAMCO 1934)"                                                                = @{ IPDBNum = 4457; Players = 1; Type = 'EM'; Theme = 'Flipperless' }
    "Contest (Gottlieb 1958)"                                                                    = @{ IPDBNum = 564; Players = 4; Type = 'EM'; Theme = 'Pinball' }
    "Contra (Original 2019)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Cool Spot (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Copa Libertadores 2018 (Original 2018)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Corinthian Master Bagatelle (Abbey 1951)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'PM'; Theme = 'Bagatelle, Flipperless' }
    "Coronation (Gottlieb 1952)"                                                                 = @{ IPDBNum = 568; Players = 1; Type = 'EM'; Theme = '' }
    "Corsario (Inder 1989)"                                                                      = @{ IPDBNum = 4090; Players = 4; Type = 'SS'; Theme = 'Pirates' }
    "Corvette (Bally 1994)"                                                                      = @{ IPDBNum = 570; Players = 4; Type = 'SS'; Theme = 'Cars' }
    "Cosmic (Taito do Brasil 1980)"                                                              = @{ IPDBNum = 4567; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Cosmic Battle Girls (Original 2025)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Anime, Kids' }
    "Cosmic Carnival (Original 2019)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = '' }
    "Cosmic Gunfight (Williams 1982)"                                                            = @{ IPDBNum = 571; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Cosmic Lady (Original 2018)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Outer Space, Mysticism' }
    "Cosmic Princess (Stern 1979)"                                                               = @{ IPDBNum = 3967; Players = 4; Type = 'SS'; Theme = 'Astrology' }
    "Cosmic Venus (Tilt Movie 1978)"                                                             = @{ IPDBNum = 5711; Players = 0; Type = 'EM'; Theme = 'Dinosaurs, Outer Space, Space Fantasy' }
    "Count-Down (Gottlieb 1979)"                                                                 = @{ IPDBNum = 573; Players = 4; Type = 'SS'; Theme = 'Outer Space, Astronauts' }
    "Counterforce (Gottlieb 1980)"                                                               = @{ IPDBNum = 575; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Courage The Cowardly Dog Pinball (Original 2025)"                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids, TV Show' }
    "Cow Poke (Gottlieb 1965)"                                                                   = @{ IPDBNum = 581; Players = 1; Type = 'EM'; Theme = 'American West' }
    "CowBoy Bebop (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Science Fiction' }
    "Cowboy Bebop Pinball (Original 2024)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Science Fiction' }
    "Cowboy Eight Ball (LTD do Brasil 1981)"                                                     = @{ IPDBNum = 5132; Players = 3; Type = 'SS'; Theme = 'Billiards' }
    "Cowboy Eight Ball 2 (LTD do Brasil 1981)"                                                   = @{ IPDBNum = 5734; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Crash Bandicoot (Original 2018)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Crazy Cats Demo Derby (Original 2023)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Demolition Derby' }
    "Crazy Rocket (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Space Fantasy, Kids' }
    "Creature from the Black Lagoon - B&W Edition (Bally 1992)"                                  = @{ IPDBNum = 588; Players = 4; Type = 'SS'; Theme = 'Drive-In, Movie, Fictional, Licensed Theme' }
    "Creature from the Black Lagoon - Nude Edition (Bally 1992)"                                 = @{ IPDBNum = 588; Players = 4; Type = 'SS'; Theme = 'Drive-In, Movie, Fictional, Licensed Theme' }
    "Creature from the Black Lagoon (Bally 1992)"                                                = @{ IPDBNum = 588; Players = 4; Type = 'SS'; Theme = 'Drive-In, Movie, Fictional, Licensed Theme' }
    "Creepshow (Original 2022)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Crescendo (Gottlieb 1970)"                                                                  = @{ IPDBNum = 590; Players = 2; Type = 'EM'; Theme = 'Music, Singing, Dancing, Psychedelic' }
    "Criterium 75 (Recel 1975)"                                                                  = @{ IPDBNum = 596; Players = 4; Type = 'EM'; Theme = 'Sports, Bicycle Racing' }
    "Criterium 77 (Taito do Brasil 1977)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Sports, Bicycle Racing' }
    "Cross Town (Gottlieb 1966)"                                                                 = @{ IPDBNum = 601; Players = 1; Type = 'EM'; Theme = 'City Living' }
    "Crow, The (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Supernatural' }
    "Crysis (Original 2018)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Crystal-Ball (Automaticos 1970)"                                                            = @{ IPDBNum = 5498; Players = 1; Type = 'EM'; Theme = 'Fortune Telling' }
    "CSI (Stern 2008)"                                                                           = @{ IPDBNum = 5348; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Detective, Crime, TV Show' }
    "Cue (Stern 1982)"                                                                           = @{ IPDBNum = 3873; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Cue Ball Wizard (Gottlieb 1992)"                                                            = @{ IPDBNum = 610; Players = 4; Type = 'SS'; Theme = 'Billiards, Celebrities, Fictional' }
    "Cuphead (Original 2019)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = '' }
    "Cuphead Pro (Perdition Edition) - PuP-Pack Edition (Original 2020)"                         = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Video Game, Kids' }
    "Cuphead Pro (Perdition Edition) (Original 2020)"                                            = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Video Game, Kids' }
    "Cure, The (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Cyber Race (Original 2023)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cyberpunk, Racing' }
    "Cybernaut (Bally 1985)"                                                                     = @{ IPDBNum = 614; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Cyclone (Williams 1988)"                                                                    = @{ IPDBNum = 617; Players = 4; Type = 'SS'; Theme = 'Happiness, Amusement Park, Roller Coasters' }
    "Cyclopes (Game Plan 1985)"                                                                  = @{ IPDBNum = 619; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "Daft Punk - Interstella 5555 (Original 2024)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Anime' }
    "Daft Punk (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Daho (Original 2024)"                                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Dale Jr. (Stern 2007)"                                                                      = @{ IPDBNum = 5292; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing, Cars' }
    "Daniel Tiger''s Neighborhood (Original 2025)"                                               = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Kids' }
    "Dante''s Inferno (Original 2022)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Horror' }
    "Daredevil and the Defenders (Original 2024)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Superheroes' }
    "Dark (1986) (Original 2024)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Time Travel' }
    "Dark Chaos (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outer Space, Space Age, Science Fiction' }
    "Dark Crystal Pinball, The (Original 2020)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Fantasy' }
    "Dark Princess (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Dark Rider (Geiger 1984)"                                                                   = @{ IPDBNum = 3968; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Dark Shadow (Nuova Bell Games 1986)"                                                        = @{ IPDBNum = 3699; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Darkest Dungeon (Original 2023)"                                                            = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Video Game' }
    "Darling (Williams 1973)"                                                                    = @{ IPDBNum = 640; Players = 2; Type = 'EM'; Theme = 'Women' }
    "Daughtry (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Day of the Tentacle (Original 2023)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Days of Thunder (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Auto Racing, Movie' }
    "Deadly Weapon (Gottlieb 1990)"                                                              = @{ IPDBNum = 645; Players = 4; Type = 'SS'; Theme = 'Crime' }
    "Dealer''s Choice (Williams 1973)"                                                           = @{ IPDBNum = 649; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Death Note (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Anime, Thriller, Mystery' }
    "Death Proof - PuP-Pack Edition (Original 2021)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Death Proof (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Death Race 2000 (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Auto Racing' }
    "Death Wish 3 (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Deep Purple - Smoke on the Water - B&W Edition (Original 2024)"                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Deep Purple - Smoke on the Water (Original 2024)"                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Def Leppard (Original 2020)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Def Leppard (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock, Heavy Metal' }
    "Def Leppard Hits Vegas (Original 2025)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Defender (Williams 1982)"                                                                   = @{ IPDBNum = 651; Players = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy, Video Game' }
    "Deftones (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Delta Force, The (Original 2019)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Celebrities, Movie' }
    "Demogorgon (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction' }
    "Demolition Man - Limited Cryo Edition (Williams 1994)"                                      = @{ IPDBNum = 662; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Licensed Theme, Movie, Action' }
    "Demolition Man (Williams 1994)"                                                             = @{ IPDBNum = 662; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Licensed Theme, Movie, Action' }
    "Dennis Lillee''s Howzat! (Hankin 1980)"                                                     = @{ IPDBNum = 3909; Players = 4; Type = 'SS'; Theme = 'Sports, Cricket' }
    "Depeche Mode Pinball (Original 2021)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Desert City (Fipermatic 1977)"                                                              = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Devil Riders (Zaccaria 1984)"                                                               = @{ IPDBNum = 672; Players = 4; Type = 'SS'; Theme = 'Stunts, Motorcycles' }
    "Devil''s Dare (Gottlieb 1982)"                                                              = @{ IPDBNum = 673; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Dexter (Original 2022)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Diablo Pinball (Original 2017)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy, Video Game' }
    "Diadem (Original 2023)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Diamond Jack (Gottlieb 1967)"                                                               = @{ IPDBNum = 676; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Diamond Lady (Gottlieb 1988)"                                                               = @{ IPDBNum = 678; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Diana (Rowamet 1981)"                                                                       = @{ IPDBNum = 0; Players = 2; Type = 'SS'; Theme = 'Exploration, Jungle, Fantasy' }
    "Dick Tracy (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Detective, Action, Fictional Characters' }
    "Die Hard Trilogy (Original 2023)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Action' }
    "Dimension (Gottlieb 1971)"                                                                  = @{ IPDBNum = 680; Players = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Dimmu Borgir (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Diner (Williams 1990)"                                                                      = @{ IPDBNum = 681; Players = 4; Type = 'SS'; Theme = 'Happiness, Food' }
    "Dipsy Doodle (Williams 1970)"                                                               = @{ IPDBNum = 683; Players = 4; Type = 'EM'; Theme = 'Happiness, Dancing' }
    "Dire Straits (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Dirty Dancing (Original 2022)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Dancing' }
    "Dirty Harry (Williams 1995)"                                                                = @{ IPDBNum = 684; Players = 4; Type = 'SS'; Theme = 'Fictional, Licensed Theme, Movie, Crime, Police' }
    "Disco (Stern 1977)"                                                                         = @{ IPDBNum = 685; Players = 2; Type = 'EM'; Theme = 'Music, Singing, Dancing' }
    "Disco Dancing (LTD do Brasil 1979)"                                                         = @{ IPDBNum = 5892; Players = 2; Type = 'SS'; Theme = 'Dancing, Happiness, Music, Nightlife' }
    "Disco Fever (Williams 1978)"                                                                = @{ IPDBNum = 686; Players = 4; Type = 'SS'; Theme = 'Happiness, Dancing' }
    "Disney Aladdin (Original 2020)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Descendants (Original 2020)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Movie, Kids' }
    "Disney Encanto (Original 2022)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Frozen (Original 2016)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Hotel Transylvania (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Movie' }
    "Disney Moana (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Pin-Up Pinball (Original 2023)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Adult' }
    "Disney Pixar Brave (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Pixar Luca (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Pixar Onward (Original 2021)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Princesses (Original 2016)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney Raya and Friends Pinball (Original 2022)"                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation' }
    "Disney Tangled (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cartoon, Kids' }
    "Disney The Lion King (Original 2020)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney The Little Mermaid (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Disney TRON Legacy (Limited Edition) - PuP-Pack Edition (Stern 2011)"                       = @{ IPDBNum = 5682; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie' }
    "Disney TRON Legacy (Limited Edition) (Stern 2011)"                                          = @{ IPDBNum = 5682; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie' }
    "Disney Vaiana (Original 2021)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Movie' }
    "Dixieland (Bally 1968)"                                                                     = @{ IPDBNum = 692; Players = 1; Type = 'EM'; Theme = 'American Places, Happiness, Music' }
    "Django Unchained (Original 2022)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'American West, Movie' }
    "Doctor Strange (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes, Movie' }
    "Doctor Who (Bally 1992)"                                                                    = @{ IPDBNum = 738; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Science Fiction, Time Travel' }
    "DOF Test Table (Original 2017)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Testing, Example' }
    "Dogelon Mars Pinball (Original 2024)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Meme Coin' }
    "Dogies (Bally 1968)"                                                                        = @{ IPDBNum = 696; Players = 4; Type = 'EM'; Theme = 'American West' }
    "Dolly Parton (Bally 1979)"                                                                  = @{ IPDBNum = 698; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music, Singing' }
    "Dolphin (Chicago Coin 1974)"                                                                = @{ IPDBNum = 699; Players = 2; Type = 'EM'; Theme = 'Aquatic Parks' }
    "Dominatrix (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Adult, Women' }
    "Domino (Gottlieb 1968)"                                                                     = @{ IPDBNum = 701; Players = 1; Type = 'EM'; Theme = 'Happiness, Games, Board Games' }
    "Domino (Gottlieb 1983)"                                                                     = @{ IPDBNum = 5334; Players = 4; Type = 'SS'; Theme = 'Dominoes, Games' }
    "Donald Duck Phantomias (Original 2022)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Doodle Bug (Williams 1971)"                                                                 = @{ IPDBNum = 703; Players = 1; Type = 'EM'; Theme = 'Dancing, Happiness, Music' }
    "Doom Classic Edition (Original 2019)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Science Fiction' }
    "Doom Eternal (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Doors, The (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music, Rock' }
    "Doraemon (Original 2020)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation, Kids' }
    "Double Barrel (Williams 1961)"                                                              = @{ IPDBNum = 709; Players = 2; Type = 'EM'; Theme = 'American West, Women' }
    "Double Dragon Neon (Original 2020)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Video Game' }
    "Double-Up (Bally 1970)"                                                                     = @{ IPDBNum = 4447; Players = 1; Type = 'EM'; Theme = 'Motorcycles' }
    "Dr. Dude and His Excellent Ray (Bally 1990)"                                                = @{ IPDBNum = 737; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional' }
    "Dr. Jekyll and Mr. Hyde (Original 2022)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Dr. Rollover''s Laboratory (Original 2025)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Anime' }
    "Dracula (Stern 1979)"                                                                       = @{ IPDBNum = 728; Players = 4; Type = 'SS'; Theme = 'Fictional, Supernatural, Horror' }
    "Dragon (Gottlieb 1978)"                                                                     = @{ IPDBNum = 4697; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Dragon (Interflip 1977)"                                                                    = @{ IPDBNum = 3887; Players = 4; Type = 'EM'; Theme = 'Fantasy, Dragons' }
    "Dragon (SS) (Gottlieb 1978)"                                                                = @{ IPDBNum = 729; Players = 4; Type = 'SS'; Theme = 'Fantasy, Dragons' }
    "Dragon Ball Z (Original 2018)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Dragon Ball Z Budokai (Original 2023)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Dragon Flames (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Fantasy' }
    "Dragon''s Lair (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Video Game' }
    "Dragonball - Super Saiyan Edition (Original 2025)"                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Anime' }
    "Dragonette (Gottlieb 1954)"                                                                 = @{ IPDBNum = 730; Players = 0; Type = 'EM'; Theme = 'Detective, Crime' }
    "DragonFire (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Dragons, Fantasy' }
    "Dragonfist (Stern 1981)"                                                                    = @{ IPDBNum = 731; Players = 4; Type = 'SS'; Theme = 'Martial Arts, Sports' }
    "Dragoon (Recreativos Franco 1977)"                                                          = @{ IPDBNum = 4872; Players = 1; Type = 'EM'; Theme = 'Fantasy, Dragons' }
    "Drakor (Taito do Brasil 1979)"                                                              = @{ IPDBNum = 4569; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Dready 4-Bushes (Original 2021)"                                                            = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = '' }
    "Dream Daddy - The Dad Dating Simulator (Original 2020)"                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Romance, Video Game' }
    "Dream Theater (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal, Progressive' }
    "DreamWorks Megamind (Original 2021)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Movie, Kids' }
    "DreamWorks Trolls (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Movie, Kids' }
    "Drink Absolut (Original 2015)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Drinking' }
    "Drop-A-Card (Gottlieb 1971)"                                                                = @{ IPDBNum = 735; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Drunken Santa (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Christmas' }
    "DuckTales (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, Video Game' }
    "Dude, The (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Bowling' }
    "Duke Nukem 3D (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Dukes of Hazzard, The (Original 2022)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Dune (Original 2024)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Dungeons & Dragons (Bally 1987)"                                                            = @{ IPDBNum = 743; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Fantasy, Dragons, Roleplaying' }
    "Duotron (Gottlieb 1974)"                                                                    = @{ IPDBNum = 744; Players = 2; Type = 'EM'; Theme = 'Fantasy' }
    "Duran Duran (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Dutch Pool (A.B.T. 1931)"                                                                   = @{ IPDBNum = 747; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Eager Beaver (Williams 1965)"                                                               = @{ IPDBNum = 752; Players = 2; Type = 'EM'; Theme = 'Fantasy' }
    "Earth Wind Fire (Zaccaria 1981)"                                                            = @{ IPDBNum = 3611; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Earthshaker (Williams 1989)"                                                                = @{ IPDBNum = 753; Players = 4; Type = 'SS'; Theme = 'Earthquake' }
    "Eclipse (Gottlieb 1982)"                                                                    = @{ IPDBNum = 756; Players = 4; Type = 'SS'; Theme = 'Mysticism' }
    "Eddie (Original 2019)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Egg Head (Gottlieb 1961)"                                                                   = @{ IPDBNum = 758; Players = 1; Type = 'EM'; Theme = 'Games, Board Games, Tic-Tac-Toe' }
    "Eight Ball (Bally 1977)"                                                                    = @{ IPDBNum = 760; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Eight Ball Champ (Bally 1985)"                                                              = @{ IPDBNum = 761; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Eight Ball Deluxe (Bally 1981)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "El Bueno el Feo y el Malo (Original 2015)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'American West, Movie' }
    "El Dorado (Gottlieb 1975)"                                                                  = @{ IPDBNum = 766; Players = 1; Type = 'EM'; Theme = 'American West' }
    "El Dorado City of Gold (Gottlieb 1984)"                                                     = @{ IPDBNum = 767; Players = 4; Type = 'SS'; Theme = 'Adventure, Fantasy' }
    "Electra-Pool (Gottlieb 1965)"                                                               = @{ IPDBNum = 779; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Electric Mayhem (Original 2016)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, TV Show' }
    "Electric State OG, The (Original 2025)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Elektra (Bally 1981)"                                                                       = @{ IPDBNum = 778; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Elf Pinball XL (Original 2018)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie' }
    "Elijah''s Batman Pinball (Original 2025)"                                                   = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Superheroes, Cartoon, Kids' }
    "Elite Guard (Gottlieb 1968)"                                                                = @{ IPDBNum = 780; Players = 1; Type = 'EM'; Theme = 'World Places, Historical' }
    "Elton John (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Elvira and the Party Monsters - Nude Edition (Bally 1989)"                                  = @{ IPDBNum = 782; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Horror, Supernatural' }
    "Elvira and the Party Monsters (Bally 1989)"                                                 = @{ IPDBNum = 782; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Horror, Supernatural' }
    "Elvira''s House of Horrors Remix - Blood Red Kiss Edition (Original 2021)"                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Elvira''s House of Horrors Remix - Blood Red Kiss PuP-Pack Edition (Original 2021)"         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Elvira''s House of Horrors Remix (Original 2021)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Elvis (Stern 2004)"                                                                         = @{ IPDBNum = 4983; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Rock, Pop, Country and Western, Blues, Soul' }
    "Elvis Gold (Limited Edition) (Stern 2004)"                                                  = @{ IPDBNum = 6032; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "Embryon (Bally 1981)"                                                                       = @{ IPDBNum = 783; Players = 4; Type = 'SS'; Theme = 'Fantasy, Science Fiction' }
    "Eminem - PuP-Pack Edition (Original 2019)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Eminem (Original 2019)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Endless Summer, The (Original 2020)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Sports, Surfing' }
    "Escape from Monkey Island (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Pirates' }
    "Escape from New York (Original 2020)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Escape from the Lost World (Bally 1988)"                                                    = @{ IPDBNum = 789; Players = 4; Type = 'SS'; Theme = 'Fantasy, Dinosaurs' }
    "Estopa (Original 2022)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Europe (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock, Heavy Metal' }
    "Evanescence (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Evel Knievel (Bally 1977)"                                                                  = @{ IPDBNum = 4499; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Stunts' }
    "Everquest II Pinball Tribute (Original 2023)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Roleplaying' }
    "Everquest Pinball Tribute (Original 2023)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Fantasy' }
    "Evil Dead (Original 2018)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "Evil Dead 2 (Original 2019)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie, Supernatural' }
    "Evil Dead 2 (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Horror, Movie, Supernatural' }
    "Evil Dead 3 Army of Darkness (Original 2020)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "Evil Fight (Playmatic 1980)"                                                                = @{ IPDBNum = 3085; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Excalibur (Gottlieb 1988)"                                                                  = @{ IPDBNum = 795; Players = 4; Type = 'SS'; Theme = 'Fantasy, Knights, Mythology' }
    "Exorcist, The (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Experiments of Alchemical Chaos (Original 2024)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Supernatural' }
    "Extremoduro Pinball (Original 2021)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Eye of the Beholder Pinball (Original 2023)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Eye Of The Tiger (Gottlieb 1978)"                                                           = @{ IPDBNum = 802; Players = 2; Type = 'EM'; Theme = 'Fantasy, Myth and Legend' }
    "F-14 Tomcat (Williams 1987)"                                                                = @{ IPDBNum = 804; Players = 4; Type = 'SS'; Theme = 'Adventure, Combat, Aviation' }
    "Faces (Sonic 1976)"                                                                         = @{ IPDBNum = 806; Players = 4; Type = 'EM'; Theme = 'Fantasy, Psychedelic' }
    "Faeton (Juegos Populares 1985)"                                                             = @{ IPDBNum = 3087; Players = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Fair Fight (Recel 1978)"                                                                    = @{ IPDBNum = 808; Players = 4; Type = 'SS'; Theme = 'Medieval, Combat' }
    "Fairy Favors (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Fantasy' }
    "Falling In Reverse (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Fallout - Season One - Vault Edition (Original 2024)"                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, TV Show, Video Game' }
    "Fallout - Season One (Original 2024)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, TV Show, Video Game' }
    "Family Guy (Stern 2007)"                                                                    = @{ IPDBNum = 5219; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Animation, TV Show' }
    "Family Guy Christmas (Original 2019)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Christmas' }
    "Fan-Tas-Tic (Williams 1972)"                                                                = @{ IPDBNum = 820; Players = 4; Type = 'EM'; Theme = 'Dancing, Happiness, Music' }
    "Far Cry 3 - Blood Dragon (Original 2018)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Far Out (Gottlieb 1974)"                                                                    = @{ IPDBNum = 823; Players = 4; Type = 'EM'; Theme = 'Psychedelic' }
    "Farfalla (Zaccaria 1983)"                                                                   = @{ IPDBNum = 824; Players = 4; Type = 'SS'; Theme = '' }
    "Farwest (Fliperbol 1980)"                                                                   = @{ IPDBNum = 4593; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Fashion Show (Gottlieb 1962)"                                                               = @{ IPDBNum = 825; Players = 2; Type = 'EM'; Theme = 'Fashion Show, Pageantry, Women' }
    "Fast and Furious (Original 2022)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Cars' }
    "Fast Draw (Gottlieb 1975)"                                                                  = @{ IPDBNum = 828; Players = 4; Type = 'EM'; Theme = 'American West' }
    "Father Ted (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Comedy' }
    "Fathom - LED Edition (Bally 1981)"                                                          = @{ IPDBNum = 829; Players = 4; Type = 'SS'; Theme = 'Fantasy, Scuba Diving, Sports, Aquatic' }
    "Fathom (Bally 1981)"                                                                        = @{ IPDBNum = 829; Players = 4; Type = 'SS'; Theme = 'Fantasy, Scuba Diving, Sports, Aquatic' }
    "Feiseanna (Original 2022)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Kids' }
    "Feiseanna II - Dream Worlds (Original 2022)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Dancing' }
    "Fifteen (Inder 1974)"                                                                       = @{ IPDBNum = 4409; Players = 1; Type = 'EM'; Theme = 'Women' }
    "Fifth Element, The (Original 2022)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Fight Night (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Sports, Boxing' }
    "Fire Action (Taito do Brasil 1980)"                                                         = @{ IPDBNum = 4570; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Fire Action De Luxe (Taito do Brasil 1983)"                                                 = @{ IPDBNum = 4552; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Fire Queen (Gottlieb 1977)"                                                                 = @{ IPDBNum = 851; Players = 2; Type = 'EM'; Theme = 'Fantasy' }
    "Fire! (Williams 1987)"                                                                      = @{ IPDBNum = 859; Players = 4; Type = 'SS'; Theme = 'Fire Fighting' }
    "Fireball (Bally 1972)"                                                                      = @{ IPDBNum = 852; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Fireball Classic (Bally 1985)"                                                              = @{ IPDBNum = 853; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Fireball II (Bally 1981)"                                                                   = @{ IPDBNum = 854; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Fireball XL5 (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Puppets, Television Series, Science Fiction' }
    "Firecracker (Bally 1971)"                                                                   = @{ IPDBNum = 855; Players = 4; Type = 'EM'; Theme = 'Celebration, Festivities' }
    "Firepower (Williams 1980)"                                                                  = @{ IPDBNum = 856; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Firepower II (Williams 1983)"                                                               = @{ IPDBNum = 857; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Firepower vs. A.I. (Williams 1980)"                                                         = @{ IPDBNum = 856; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Fish Tales (Williams 1992)"                                                                 = @{ IPDBNum = 861; Players = 4; Type = 'SS'; Theme = 'Sports, Fishing' }
    "Five Finger Death Punch (Original 2023)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Five Nights at Freddy''s (Original 2021)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Five Nights at Freddy''s Pizza Party (Original 2020)"                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "FJ (Hankin 1978)"                                                                           = @{ IPDBNum = 3627; Players = 4; Type = 'SS'; Theme = 'Cars' }
    "Flash - Comic Verison, The (Original 2024)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Flash (Williams 1979)"                                                                      = @{ IPDBNum = 871; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Flash Dragon (Playmatic 1986)"                                                              = @{ IPDBNum = 3616; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Flash Gordon (Bally 1981)"                                                                  = @{ IPDBNum = 874; Players = 4; Type = 'SS'; Theme = 'Fictional Characters' }
    "Flash, The (Original 2018)"                                                                 = @{ IPDBNum = 871; Players = 4; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Flashman (Sport matic 1984)"                                                                = @{ IPDBNum = 5218; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Fleet Jr. (Bally 1934)"                                                                     = @{ IPDBNum = 880; Players = 1; Type = 'EM'; Theme = 'Flipperless' }
    "Fleetwood Mac (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Flicker (Bally 1975)"                                                                       = @{ IPDBNum = 883; Players = 2; Type = 'EM'; Theme = 'Show Business, Celebrities' }
    "Flight 2000 (Stern 1980)"                                                                   = @{ IPDBNum = 887; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Flintstones, The - Cartoon Edition (Williams 1994)"                                         = @{ IPDBNum = 888; Players = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie' }
    "Flintstones, The - The Cartoon VR Edition (Williams 1994)"                                  = @{ IPDBNum = 888; Players = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie' }
    "Flintstones, The - VR Cartoon Edition (Williams 1994)"                                      = @{ IPDBNum = 888; Players = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie' }
    "Flintstones, The - Yabba Dabba Re-Doo Edition (Williams 1994)"                              = @{ IPDBNum = 888; Players = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie' }
    "Flintstones, The (Williams 1994)"                                                           = @{ IPDBNum = 888; Players = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme, Movie' }
    "Flip a Card (Gottlieb 1970)"                                                                = @{ IPDBNum = 890; Players = 1; Type = 'EM'; Theme = 'College Life, Happiness, Music, Cards' }
    "Flip Flop (Bally 1976)"                                                                     = @{ IPDBNum = 889; Players = 4; Type = 'EM'; Theme = 'American West, Rodeo' }
    "Flipper Fair (Gottlieb 1961)"                                                               = @{ IPDBNum = 894; Players = 1; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Flipper Football (Capcom 1996)"                                                             = @{ IPDBNum = 3945; Players = 6; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Flipper Pool (Gottlieb 1965)"                                                               = @{ IPDBNum = 896; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Floopy Bat (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'DG'; Theme = 'Video Game' }
    "Flower Man, The (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Gardening, Flowers' }
    "Fly, The (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Flying Carpet (Gottlieb 1972)"                                                              = @{ IPDBNum = 899; Players = 1; Type = 'EM'; Theme = 'Fantasy, Mythology' }
    "Flying Chariots (Gottlieb 1963)"                                                            = @{ IPDBNum = 901; Players = 2; Type = 'EM'; Theme = 'Historical' }
    "Flying Turns (Midway 1964)"                                                                 = @{ IPDBNum = 910; Players = 2; Type = 'EM'; Theme = 'Sports, Auto Racing' }
    "Fog, The (Original 2020)"                                                                   = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Movie, Horror' }
    "Foo Fighters (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Football (Taito do Brasil 1979)"                                                            = @{ IPDBNum = 5199; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Force (LTD do Brasil 1979)"                                                                 = @{ IPDBNum = 5893; Players = 2; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Force II (Gottlieb 1981)"                                                                   = @{ IPDBNum = 916; Players = 4; Type = 'SS'; Theme = 'Combat, Aliens, Outer Space' }
    "Foreigner (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music, Rock' }
    "Forge (Original 2023)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Forgotten Planet - Murray Leinster, The (Original 2024)"                                    = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction' }
    "Forrest Gump (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Fortnite (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Four Million B.C. (Bally 1971)"                                                             = @{ IPDBNum = 935; Players = 4; Type = 'EM'; Theme = 'Dinosaurs, Historical' }
    "Four Seasons (Gottlieb 1968)"                                                               = @{ IPDBNum = 939; Players = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Recreation, Water Skiing, Ice Skating, Hunting' }
    "Frank Thomas'' Big Hurt (Gottlieb 1995)"                                                    = @{ IPDBNum = 3591; Players = 4; Type = 'SS'; Theme = 'Sports, Baseball' }
    "Freddy - A Nightmare on Elm Street (Gottlieb 1994)"                                         = @{ IPDBNum = 948; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Horror, Movie' }
    "Freddy''s Nightmares (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Adult' }
    "Free Fall (Gottlieb 1974)"                                                                  = @{ IPDBNum = 949; Players = 1; Type = 'EM'; Theme = 'Parachuting, Sports, Skydiving' }
    "Freedom (EM) (Bally 1976)"                                                                  = @{ IPDBNum = 952; Players = 4; Type = 'EM'; Theme = 'American History, Celebration' }
    "Freedom (SS) (Bally 1976)"                                                                  = @{ IPDBNum = 4500; Players = 4; Type = 'SS'; Theme = 'American History, Celebration' }
    "Freefall (Stern 1981)"                                                                      = @{ IPDBNum = 953; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Friday the 13th (Original 2017)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Friday the 13th (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "Friday the 13th Part II (Original 2019)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror' }
    "From Dusk Till Dawn (Original 2022)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Frontier (Bally 1980)"                                                                      = @{ IPDBNum = 959; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Full (Recreativos Franco 1977)"                                                             = @{ IPDBNum = 4707; Players = 1; Type = 'EM'; Theme = 'Sports, Bowling' }
    "Full House (Williams 1966)"                                                                 = @{ IPDBNum = 961; Players = 1; Type = 'EM'; Theme = 'American West, Cards, Gambling' }
    "Full Metal Jacket (Original 2022)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Combat' }
    "Full Throttle (Original 2023)"                                                              = @{ IPDBNum = 6301; Players = 0; Type = 'SS'; Theme = 'Sports, Motorcycle Racing' }
    "Fullmetal Alchemist (Original 2007)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Anime' }
    "Fun Fair (Gottlieb 1968)"                                                                   = @{ IPDBNum = 964; Players = 1; Type = 'EM'; Theme = 'Carnival, Shooting Gallery' }
    "Fun Land (Gottlieb 1968)"                                                                   = @{ IPDBNum = 973; Players = 1; Type = 'EM'; Theme = 'Amusement Park' }
    "Fun Park (Gottlieb 1968)"                                                                   = @{ IPDBNum = 968; Players = 1; Type = 'EM'; Theme = 'Carnival, Shooting Gallery' }
    "Fun-Fest (Williams 1972)"                                                                   = @{ IPDBNum = 972; Players = 4; Type = 'EM'; Theme = 'Music, Dancing, People, Singing' }
    "Funhouse (Williams 1990)"                                                                   = @{ IPDBNum = 966; Players = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival' }
    "Futurama (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Science Fiction, Comedy' }
    "Future Spa (Bally 1979)"                                                                    = @{ IPDBNum = 974; Players = 4; Type = 'SS'; Theme = 'Fitness, Fantasy, Relaxation' }
    "Galaga Pinball (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Galaxia (LTD do Brasil 1975)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Outer Space' }
    "Galaxie (Gottlieb 1971)"                                                                    = @{ IPDBNum = 978; Players = 1; Type = 'EM'; Theme = 'Science Fiction, Outer Space' }
    "Galaxy (Sega 1973)"                                                                         = @{ IPDBNum = 979; Players = 1; Type = 'EM'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Galaxy (Stern 1980)"                                                                        = @{ IPDBNum = 980; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Galaxy Play (CIC Play 1986)"                                                                = @{ IPDBNum = 4631; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Galaxy Quest - PuP-Pack Edition (Original 2020)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outer Space, Movie' }
    "Galaxy Quest (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outer Space, Movie' }
    "Gamatron (Pinstar 1985)"                                                                    = @{ IPDBNum = 984; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Gamatron (Sonic 1986)"                                                                      = @{ IPDBNum = 3116; Players = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction' }
    "Gamblin Daze (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Gambling' }
    "Game of Thrones (Limited Edition) (Stern 2015)"                                             = @{ IPDBNum = 6309; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Medieval, Fantasy, Dragons' }
    "Game of Thrones (Original 2021)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Medieval, TV Show' }
    "Games I, The (Gottlieb 1983)"                                                               = @{ IPDBNum = 5340; Players = 4; Type = 'SS'; Theme = 'Sports, Olympic Competition' }
    "Games, The (Gottlieb 1984)"                                                                 = @{ IPDBNum = 3391; Players = 4; Type = 'SS'; Theme = 'Sports, Olympic Games' }
    "Gargamel Park (Original 2016)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Gaston Pinball Machine, The (Original 2020)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Comics' }
    "Gaucho (Gottlieb 1963)"                                                                     = @{ IPDBNum = 988; Players = 4; Type = 'EM'; Theme = 'Adventure, World Culture' }
    "Gay 90''s (Williams 1970)"                                                                  = @{ IPDBNum = 989; Players = 4; Type = 'EM'; Theme = 'American History, Historical' }
    "GEEGA (Original 2025)"                                                                      = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Anime' }
    "Gemini (Gottlieb 1978)"                                                                     = @{ IPDBNum = 995; Players = 2; Type = 'EM'; Theme = 'Astrology, Fantasy' }
    "Gemini 2000 (Taito do Brasil 1982)"                                                         = @{ IPDBNum = 4579; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Genesis (Gottlieb 1986)"                                                                    = @{ IPDBNum = 996; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Genesis (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Genie - Fuzzel Physics Edition (Gottlieb 1979)"                                             = @{ IPDBNum = 997; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Genie (Gottlieb 1979)"                                                                      = @{ IPDBNum = 997; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "George Michael - Faith (Original 2023)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Get Smart (Original 2021)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Getaway - High Speed II, The (Williams 1992)"                                               = @{ IPDBNum = 1000; Players = 4; Type = 'SS'; Theme = 'Police, Speeding, Cars' }
    "Ghost (Original 2023)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Rock' }
    "Ghost Ramps and DMD Test (Original 2016)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Testing' }
    "Ghost Toys VPX Model Pack (Original 2016)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Ghostbusters (Limited Edition) (Stern 2016)"                                                = @{ IPDBNum = 6334; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Supernatural, Movie' }
    "Ghosts ''n Goblins (Original 2018)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Gigi (Gottlieb 1963)"                                                                       = @{ IPDBNum = 1003; Players = 1; Type = 'EM'; Theme = 'Circus, Carnival' }
    "Gilligan''s Island (Bally 1991)"                                                            = @{ IPDBNum = 1004; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme' }
    "Gladiators (Gottlieb 1993)"                                                                 = @{ IPDBNum = 1011; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Gnome Slayer Yuki (Original 2024)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Anime' }
    "Godfather, The (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Crime' }
    "Godzilla (Sega 1998)"                                                                       = @{ IPDBNum = 4443; Players = 6; Type = 'SS'; Theme = 'Licensed Theme, Fantasy, Monsters' }
    "Godzilla Remix (Limited Edition)  - 70th Anniversary Premium Edition (Original 2021)"       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Movie, Monsters' }
    "Godzilla Remix (Limited Edition)  (Original 2021)"                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Movie, Monsters' }
    "Godzilla vs. Kong (Original 2023)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Movie, Monsters' }
    "Goin'' Nuts (Gottlieb 1983)"                                                                = @{ IPDBNum = 1021; Players = 4; Type = 'SS'; Theme = 'Wildlife' }
    "Gold Ball (Bally 1983)"                                                                     = @{ IPDBNum = 1024; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Gold Crown (Pierce 1932)"                                                                   = @{ IPDBNum = 1026; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Gold Mine (Williams 1988)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling, Flipperless' }
    "Gold Rush (Williams 1971)"                                                                  = @{ IPDBNum = 1036; Players = 4; Type = 'EM'; Theme = 'Canadian West, Prospecting' }
    "Gold Star (Gottlieb 1954)"                                                                  = @{ IPDBNum = 1038; Players = 1; Type = 'EM'; Theme = '' }
    "Gold Strike (Gottlieb 1975)"                                                                = @{ IPDBNum = 1042; Players = 1; Type = 'EM'; Theme = 'American West, Prospecting' }
    "Gold Wings (Gottlieb 1986)"                                                                 = @{ IPDBNum = 1043; Players = 4; Type = 'SS'; Theme = 'Aviation, Combat' }
    "Golden Arrow (Gottlieb 1977)"                                                               = @{ IPDBNum = 1044; Players = 1; Type = 'EM'; Theme = 'American West, Native Americans, Warriors' }
    "Golden Axe (Original 2018)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Golden Birds (Original 2015)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Golden Cue (Sega 1998)"                                                                     = @{ IPDBNum = 4383; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Goldeneye (Sega 1996)"                                                                      = @{ IPDBNum = 3792; Players = 6; Type = 'SS'; Theme = 'Licensed Theme, Movie, Espionage' }
    "Goldorak - UFO Robot Goldrake (Original 2017)"                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, TV Show, Robots' }
    "Goldorak - UFO Robot Grendizer (Original 2017)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, TV Show, Robots' }
    "Goldorak (Original 2017)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, TV Show, Robots' }
    "GoldWing (Original 2018)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Motorcycles' }
    "Gollum - The Rings of Power Edition (Original 2023)"                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy' }
    "Goonies Never Say Die Pinball, The - French Edition (Original 2021)"                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Adventure, Kids' }
    "Goonies Never Say Die Pinball, The (Original 2021)"                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Adventure, Kids' }
    "Goonies Pinball Adventure, The (Original 2019)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Adventure, Kids' }
    "Gorgar (Williams 1979)"                                                                     = @{ IPDBNum = 1062; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Gorillaz (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Gork (Taito do Brasil 1982)"                                                                = @{ IPDBNum = 4590; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Gradius (Original 2017)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Science Fiction' }
    "Grand Casino (J.P. Seeburg 1934)"                                                           = @{ IPDBNum = 4194; Players = 1; Type = 'EM'; Theme = 'Flipperless' }
    "Grand Lizard (Williams 1986)"                                                               = @{ IPDBNum = 1070; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Grand Prix (LTD do Brasil 1977)"                                                            = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Auto Racing' }
    "Grand Prix (Stern 2005)"                                                                    = @{ IPDBNum = 5120; Players = 0; Type = 'SS'; Theme = '' }
    "Grand Prix (Williams 1976)"                                                                 = @{ IPDBNum = 1072; Players = 4; Type = 'EM'; Theme = 'Sports, Auto Racing' }
    "Grand Slam (Bally 1983)"                                                                    = @{ IPDBNum = 1079; Players = 4; Type = 'SS'; Theme = 'Sports, Baseball' }
    "Grand Slam (Gottlieb 1972)"                                                                 = @{ IPDBNum = 1078; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Grand Tour (Bally 1964)"                                                                    = @{ IPDBNum = 1081; Players = 1; Type = 'EM'; Theme = 'Travel, World Places' }
    "Grande Domino (Gottlieb 1968)"                                                              = @{ IPDBNum = 1069; Players = 1; Type = 'EM'; Theme = 'Dominoes, Games, Board Games' }
    "Granny and the Gators (Bally 1984)"                                                         = @{ IPDBNum = 1083; Players = 2; Type = 'SS'; Theme = 'Hunting, Aquatic' }
    "Grateful Dead (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Grease (Original 2020)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Musical' }
    "Great Giana Sisters, The (Original 2018)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Great Houdini (Original 2022)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Magic' }
    "Greedo''s Cantina Pinball (Original 2019)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Green Day - American Idiot (Original 2025)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Green Day - Dookie (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Green Lantern (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Gremlins (Original 2022)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Comedy, Movie' }
    "Gremlins Pinball (Original 2019)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie' }
    "Gridiron (Gottlieb 1977)"                                                                   = @{ IPDBNum = 1089; Players = 2; Type = 'EM'; Theme = 'Sports, American Football' }
    "Grillshow The Pinball Adventure (Original 2019)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Food' }
    "Grinch Pinball, The (Original 2020)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie' }
    "Grinch, The (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Christmas, Kids' }
    "Grinch''s How to Steal Christmas, The (Original 2025)"                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Animation, Kids' }
    "Groovy (Gottlieb 1970)"                                                                     = @{ IPDBNum = 1091; Players = 4; Type = 'EM'; Theme = 'Psychedelic, Flower Power' }
    "Guardians of the Galaxy (Pro) (Stern 2017)"                                                 = @{ IPDBNum = 6474; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes, Movie' }
    "Guardians of the Galaxy Trilogy (Original 2023)"                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes, Movie' }
    "Gulfstream (Williams 1973)"                                                                 = @{ IPDBNum = 1094; Players = 1; Type = 'EM'; Theme = 'Sports, Aquatic' }
    "Gun Men (Staal 1979)"                                                                       = @{ IPDBNum = 3131; Players = 4; Type = 'SS'; Theme = 'Western' }
    "Gundam Wing (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Guns N'' Roses (Data East 1994)"                                                            = @{ IPDBNum = 1100; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music' }
    "Guns N'' Roses Remix (Original 2021)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Gunship (Original 2023)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Hairy-Singers (Rally 1966)"                                                                 = @{ IPDBNum = 3133; Players = 1; Type = 'EM'; Theme = 'Singing, Prehistoric' }
    "Half-Life (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Hall & Oates (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Halley Comet - Alternate Plastics Edition (Juegos Populares 1986)"                          = @{ IPDBNum = 3936; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Halley Comet (Juegos Populares 1986)"                                                       = @{ IPDBNum = 3936; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Halloween (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Supernatural, Horror' }
    "Halloween (Original 2023)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Halloween 1978-1981 (Original 2022)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "Halloween Michael Myers Pinball Adventures (Original 2018)"                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Halo (Original 2021)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Video Game' }
    "Hamilton (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Musical' }
    "Hanafuda Garden (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Cards' }
    "Hang Glider (Bally 1976)"                                                                   = @{ IPDBNum = 1112; Players = 4; Type = 'EM'; Theme = 'Sports, Hang Gliding' }
    "Hank Williams Pinball (Original 2022)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Hannibal Lecter (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, TV Show, Horror' }
    "Hans Zimmer (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Movie' }
    "Happy Tree Friends X-mas Pinball (Original 2025)"                                           = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Christmas, Cartoon, Kids' }
    "Hardbody (Bally 1987)"                                                                      = @{ IPDBNum = 1122; Players = 4; Type = 'SS'; Theme = 'Exercise, Body Building' }
    "Harlem Globetrotters on Tour (Bally 1979)"                                                  = @{ IPDBNum = 1125; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball, Licensed Theme' }
    "Harley Quinn - B&W Edition (Original 2017)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Harley Quinn (Original 2017)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Harley-Davidson (Bally 1991)"                                                               = @{ IPDBNum = 1126; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Motorcycles' }
    "Harley-Davidson (Sega 1999)"                                                                = @{ IPDBNum = 4453; Players = 6; Type = 'SS'; Theme = 'Licensed Theme, Motorcycles' }
    "Harmony (Gottlieb 1967)"                                                                    = @{ IPDBNum = 1127; Players = 1; Type = 'EM'; Theme = 'Happiness, Singing' }
    "Harry Potter and the Goblet of Fire (Original 2020)"                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Harry Potter and the Prisoner of Azkaban (Original 2021)"                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Wizards, Fantasy' }
    "Harvest Frenzy (Original 2025)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Harvesters, Kids' }
    "Hateful Eight, The (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, American West' }
    "Haunted Hotel (LTD do Brasil 1983)"                                                         = @{ IPDBNum = 5704; Players = 4; Type = 'SS'; Theme = 'Adventure, Supernatural' }
    "Haunted House (Gottlieb 1982)"                                                              = @{ IPDBNum = 1133; Players = 4; Type = 'SS'; Theme = 'Adventure, Supernatural' }
    "Hawkman (Taito do Brasil 1983)"                                                             = @{ IPDBNum = 4512; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Hayburners (Williams 1951)"                                                                 = @{ IPDBNum = 1142; Players = 1; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Hearts and Spades (Gottlieb 1969)"                                                          = @{ IPDBNum = 1145; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Hearts Gain (Inder 1971)"                                                                   = @{ IPDBNum = 4406; Players = 1; Type = 'EM'; Theme = 'Gambling, Cards' }
    "Heat Ray Heist (Original 2025)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Crime' }
    "Heat Wave (Williams 1964)"                                                                  = @{ IPDBNum = 1148; Players = 1; Type = 'EM'; Theme = 'Beach, Swimming' }
    "Heavy Fire (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Combat' }
    "Heavy Metal (Rowamet 1981)"                                                                 = @{ IPDBNum = 5175; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Heavy Metal Meltdown (Bally 1987)"                                                          = @{ IPDBNum = 1150; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Heineken (Original 2020)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Drinking, Beer' }
    "Hellboy Pinball (Original 2024)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Action, Superheroes' }
    "Hellfire (Original 2021)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Hellraiser (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Licensed, Horror, Supernatural' }
    "Hercules (Atari 1979)"                                                                      = @{ IPDBNum = 1155; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "Hextech (Original 2016)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Hi-Deal (Bally 1975)"                                                                       = @{ IPDBNum = 1157; Players = 1; Type = 'EM'; Theme = 'Aircraft, Aviation, City Buildings, City Scene, Cards' }
    "Hi-Diver (Gottlieb 1959)"                                                                   = @{ IPDBNum = 1165; Players = 1; Type = 'EM'; Theme = 'Aquatic, Diving' }
    "Hi-Lo (Gottlieb 1969)"                                                                      = @{ IPDBNum = 1184; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Hi-Lo Ace (Bally 1973)"                                                                     = @{ IPDBNum = 1187; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Hi-Score (Gottlieb 1967)"                                                                   = @{ IPDBNum = 1160; Players = 4; Type = 'EM'; Theme = 'Sports, Pinball' }
    "Hi-Score Pool (Chicago Coin 1971)"                                                          = @{ IPDBNum = 1161; Players = 2; Type = 'EM'; Theme = 'Billiards' }
    "Hi-Skor (Hi-Skor 1932)"                                                                     = @{ IPDBNum = 5225; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "High Hand (Gottlieb 1973)"                                                                  = @{ IPDBNum = 1173; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "High Roller Casino (Stern 2001)"                                                            = @{ IPDBNum = 4502; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "High Seas (Gottlieb 1976)"                                                                  = @{ IPDBNum = 1175; Players = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical' }
    "High Speed (Williams 1986)"                                                                 = @{ IPDBNum = 1176; Players = 4; Type = 'SS'; Theme = 'Cars, Police, Speeding' }
    "Highlander (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Movie' }
    "Hiphop (Original 2024)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Rap' }
    "Hit the Deck (Gottlieb 1978)"                                                               = @{ IPDBNum = 1201; Players = 1; Type = 'EM'; Theme = 'Cards, Aquatic, Mythology' }
    "Hokus Pokus (Bally 1976)"                                                                   = @{ IPDBNum = 1206; Players = 2; Type = 'EM'; Theme = 'Magic, Show Business' }
    "Hollywood Heat (Gottlieb 1986)"                                                             = @{ IPDBNum = 1219; Players = 4; Type = 'SS'; Theme = 'Fictional' }
    "Home Alone (Original 2019)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie, Kids' }
    "Home Alone (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Kids' }
    "Home Alone 2 (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie, Kids' }
    "Home Run (Gottlieb 1971)"                                                                   = @{ IPDBNum = 1224; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Honey (Williams 1971)"                                                                      = @{ IPDBNum = 1230; Players = 4; Type = 'EM'; Theme = 'Women, Romance' }
    "Hong Kong Phooey (Original 2025)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Kids, Animation, Cartoon' }
    "Hook (Data East 1992)"                                                                      = @{ IPDBNum = 1233; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Pirates, Fictional, Movie' }
    "Hoops (Gottlieb 1991)"                                                                      = @{ IPDBNum = 1235; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball' }
    "Hootenanny (Bally 1963)"                                                                    = @{ IPDBNum = 1236; Players = 1; Type = 'EM'; Theme = 'Music, Singing, Dancing' }
    "Horrorburg (Original 2023)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Horseshoe (A.B.T. 1931)"                                                                    = @{ IPDBNum = 3158; Players = 1; Type = 'PM'; Theme = 'Flipperless, Games' }
    "Hot Ball (Taito do Brasil 1979)"                                                            = @{ IPDBNum = 4665; Players = 4; Type = 'SS'; Theme = 'Sports, Billiards' }
    "Hot Hand (Stern 1979)"                                                                      = @{ IPDBNum = 1244; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Hot Line (Williams 1966)"                                                                   = @{ IPDBNum = 1245; Players = 1; Type = 'EM'; Theme = 'Sports, Fishing' }
    "Hot Shot (Gottlieb 1973)"                                                                   = @{ IPDBNum = 1247; Players = 4; Type = 'EM'; Theme = 'Billiards' }
    "Hot Shots (Gottlieb 1989)"                                                                  = @{ IPDBNum = 1248; Players = 4; Type = 'SS'; Theme = 'Circus, Carnival' }
    "Hot Tip - Less Reflections Edition (Williams 1977)"                                         = @{ IPDBNum = 3163; Players = 4; Type = 'SS'; Theme = 'Sports, Horse Racing' }
    "Hot Tip (Williams 1977)"                                                                    = @{ IPDBNum = 3163; Players = 4; Type = 'SS'; Theme = 'Sports, Horse Racing' }
    "Hot Wheels (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cars, Toy Franchise' }
    "Hotdoggin'' (Bally 1980)"                                                                   = @{ IPDBNum = 1243; Players = 4; Type = 'SS'; Theme = 'Sports, Skiing' }
    "Houdini (Original 2019)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Magic' }
    "House of Diamonds (Zaccaria 1978)"                                                          = @{ IPDBNum = 3165; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Howl Against The Chains - Lunar Howl 2 (Original 2025)"                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Rock, Anime, Kids' }
    "Humpty Dumpty (Gottlieb 1947)"                                                              = @{ IPDBNum = 1254; Players = 1; Type = 'EM'; Theme = 'Fictional Characters, Flipperless' }
    "Hunter (Jennings 1935)"                                                                     = @{ IPDBNum = 1255; Players = 1; Type = 'PM'; Theme = 'Sports, Hunting, Flipperless' }
    "Hurricane (Williams 1991)"                                                                  = @{ IPDBNum = 1257; Players = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival, Roller Coasters, Amusement Park' }
    "Hustler (LTD do Brasil 1980)"                                                               = @{ IPDBNum = 6706; Players = 2; Type = 'EM'; Theme = 'Sports, Billiards' }
    "Hyperball - Analog Joystick Edition (Williams 1981)"                                        = @{ IPDBNum = 3169; Players = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Hyperball - Analog Mouse Edition (Williams 1981)"                                           = @{ IPDBNum = 3169; Players = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Hyperball (Williams 1981)"                                                                  = @{ IPDBNum = 3169; Players = 2; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "I Dream of Jeannie (Original 2019)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "I.G.F. Interstellar Ground Force (Original 2025)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Science Fiction' }
    "Ice Age - A Mammoth Xmas Pinball (Original 2020)"                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Animation, Kids, Movie' }
    "Ice Age Christmas (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Christmas, Animation, Kids, Movie' }
    "Ice Cold Beer (Taito 1983)"                                                                 = @{ IPDBNum = 6802; Players = 2; Type = 'EM'; Theme = 'Drinking, Flipperless, Beer' }
    "Ice Fever (Gottlieb 1985)"                                                                  = @{ IPDBNum = 1260; Players = 4; Type = 'SS'; Theme = 'Sports, Hockey' }
    "Impacto (Recreativos Franco 1975)"                                                          = @{ IPDBNum = 4868; Players = 1; Type = 'EM'; Theme = 'Circus' }
    "Impractical Jokers (Original 2015)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'TV Show' }
    "Incredible Hulk, The (Gottlieb 1979)"                                                       = @{ IPDBNum = 1266; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes' }
    "Independence Day (Sega 1996)"                                                               = @{ IPDBNum = 3878; Players = 6; Type = 'SS'; Theme = 'Outer Space, Licensed Theme, Movie' }
    "Indiana Jones - The Last Movie (Original 2023)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Indiana Jones - The Pinball Adventure (Williams 1993)"                                      = @{ IPDBNum = 1267; Players = 4; Type = 'SS'; Theme = 'Adventure, Fictional, Licensed Theme, Movie' }
    "Indiana Jones (Stern 2008)"                                                                 = @{ IPDBNum = 5306; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Mythology, Movie, Adventure' }
    "Indianapolis 500 (Bally 1995)"                                                              = @{ IPDBNum = 2853; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Indochine (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Indochine Central Tour (Original 2023)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Infectious Grooves (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Information Society (Original 2025)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Inhabiting Mars (Original 2023)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Exploration, Science Fiction' }
    "Inspector Gadget (Original 2021)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Cartoon, Kids' }
    "Insus, The (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Inuyasha - Special Edition (Original 2022)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Inuyasha (Original 2022)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Invader (Original 2020)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = '' }
    "Ipanema (LTD do Brasil 1976)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Beach' }
    "Iron Balls (Unidesa 1987)"                                                                  = @{ IPDBNum = 4426; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Iron Eagle (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Aircraft, Movie' }
    "Iron Maiden (Original 2019)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Iron Maiden (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Iron Maiden (Stern 1982)"                                                                   = @{ IPDBNum = 1270; Players = 4; Type = 'SS'; Theme = 'Fantasy, Music, Rock n roll' }
    "Iron Maiden Legacy of the Beast - Limited Edition (Stern 2018)"                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Iron Maiden Legacy of the Beast - Pro (Stern 2018)"                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Iron Maiden Senjutsu (Original 2021)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Iron Maiden Virtual Time - PuP-Pack Edition (Original 2020)"                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Iron Maiden Virtual Time (Original 2020)"                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Iron Man (Pro Vault Edition) (Stern 2014)"                                                  = @{ IPDBNum = 6154; Players = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Movie, Superheroes' }
    "Iron Man (Stern 2010)"                                                                      = @{ IPDBNum = 5550; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Fantasy, Superheroes, Movie' }
    "Iron Mike Tyson (Original 2024)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Boxing' }
    "It Pinball Madness (Original 2022)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "J6 Insurrection (Original 2022)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Jack Daniel''s (Original 2020)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Drinking' }
    "Jack Daniel''s 2 (Original 2021)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Drinking' }
    "Jack in the Box (Gottlieb 1973)"                                                            = @{ IPDBNum = 1277; Players = 4; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Jack Sparrow (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Pirates' }
    "Jack-Bot (Williams 1995)"                                                                   = @{ IPDBNum = 3619; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Gambling' }
    "Jackpot (Williams 1971)"                                                                    = @{ IPDBNum = 1279; Players = 4; Type = 'EM'; Theme = 'Canadian West, Prospecting' }
    "Jacks Open (Gottlieb 1977)"                                                                 = @{ IPDBNum = 1281; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Jacks to Open (Gottlieb 1984)"                                                              = @{ IPDBNum = 1282; Players = 4; Type = 'SS'; Theme = 'Gambling, Cards, Poker' }
    "Jake Mate (Recel 1974)"                                                                     = @{ IPDBNum = 1283; Players = 1; Type = 'EM'; Theme = 'Chess' }
    "Jalisco (Recreativos Franco 1976)"                                                          = @{ IPDBNum = 4667; Players = 1; Type = 'EM'; Theme = 'Mexico' }
    "Jalopy (Williams 1951)"                                                                     = @{ IPDBNum = 1284; Players = 1; Type = 'EM'; Theme = 'Sports, Auto Racing' }
    "James Bond (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 6; Type = 'SS'; Theme = 'Movie, Espionage' }
    "James Bond 007 (Gottlieb 1980)"                                                             = @{ IPDBNum = 1286; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Espionage' }
    "James Cameron''s Avatar (Stern 2010)"                                                       = @{ IPDBNum = 5618; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Science Fiction' }
    "Jaws - 50th Anniversary (Original 2025)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fishing, Movie' }
    "Jaws (Original 2013)"                                                                       = @{ IPDBNum = 0; Players = 3; Type = 'SS'; Theme = 'Movie, Horror' }
    "Jayce and the Wheeled Warriors (Original 2024)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Animation, Kids' }
    "Jeepers Creepers (Original 2024)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Horror' }
    "Jeff Wayne''s Musical Version of War Of The Worlds (Original 2025)"                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Musical, Movie, Aliens, Space Fantasy' }
    "Jet Set Radio Pinball (Original 2020)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Jet Spin (Gottlieb 1977)"                                                                   = @{ IPDBNum = 1290; Players = 4; Type = 'EM'; Theme = 'Fantasy, Recreation' }
    "Jets (Original 2023)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Sports, American Football' }
    "Jimi Hendrix (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Jive Time (Williams 1970)"                                                                  = @{ IPDBNum = 1298; Players = 1; Type = 'EM'; Theme = 'Music, Singing' }
    "Joe Bar Team (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics' }
    "Joe Bonamassa (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Joe Cocker (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock, Blues' }
    "Joe Satriani (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "John Carpenter''s Christine (Original 2019)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie' }
    "John Carpenter''s The Thing (Original 2019)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror' }
    "John Rambo (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 5; Type = 'EM'; Theme = 'Action, Movie' }
    "John Wick - BABA YAGA Pinball Edition (Original 2023)"                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Action' }
    "Johnny Cash Pinball (Original 2022)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Johnny Hallyday (Original 2020)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Johnny Mnemonic (Williams 1995)"                                                            = @{ IPDBNum = 3683; Players = 4; Type = 'SS'; Theme = 'Movie, Fictional, Licensed Theme' }
    "Joker (Gottlieb 1950)"                                                                      = @{ IPDBNum = 1304; Players = 1; Type = 'EM'; Theme = 'Gambling, Cards, Poker' }
    "Joker Poker (EM) (Gottlieb 1978)"                                                           = @{ IPDBNum = 5078; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Joker Poker (SS) (Gottlieb 1978)"                                                           = @{ IPDBNum = 1306; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Joker Wild (Bally 1970)"                                                                    = @{ IPDBNum = 3573; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Jokerz! (Williams 1988)"                                                                    = @{ IPDBNum = 1308; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Jolly Park (Spinball S.A.L. 1996)"                                                          = @{ IPDBNum = 4618; Players = 4; Type = 'SS'; Theme = 'Amusement Park, Roller Coasters' }
    "Jolly Park Oktoberfest (Original 2024)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Amusement Park, Funfair, Oktoberfest, Beer, Drinking' }
    "Jolly Roger (Williams 1967)"                                                                = @{ IPDBNum = 1314; Players = 4; Type = 'EM'; Theme = 'Historical, Pirates' }
    "Joust (Bally 1969)"                                                                         = @{ IPDBNum = 1317; Players = 2; Type = 'EM'; Theme = 'Medieval, Knights' }
    "Joust (Williams 1983)"                                                                      = @{ IPDBNum = 1316; Players = 2; Type = 'SS'; Theme = 'Video Game' }
    "JP''s Addams Family (Bally 1992)"                                                           = @{ IPDBNum = 20; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie' }
    "JP''s Captain Fantastic (Bally 1976)"                                                       = @{ IPDBNum = 438; Players = 4; Type = 'EM'; Theme = 'Celebrities, Fictional, Licensed Theme' }
    "JP''s Cyclone (Original 2022)"                                                              = @{ IPDBNum = 617; Players = 4; Type = 'SS'; Theme = 'Happiness, Amusement Park, Roller Coasters' }
    "JP''s Dale Jr. Nascar (Original 2020)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "JP''s Deadpool - Gold Edition (Original 2021)"                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes' }
    "JP''s Deadpool (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes' }
    "JP''s Foo Fighters (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "JP''s Friday the 13th (Original 2021)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "JP''s Ghostbusters Slimer (Original 2017)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction' }
    "JP''s Grand Prix (Stern 2005)"                                                              = @{ IPDBNum = 5120; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "JP''s Indiana Jones (Stern 2008)"                                                           = @{ IPDBNum = 5306; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Mythology' }
    "JP''s Iron Man 2 - Armored Adventures (Original 2018)"                                      = @{ IPDBNum = 6154; Players = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes' }
    "JP''s Mephisto (Cirsa 1987)"                                                                = @{ IPDBNum = 4077; Players = 4; Type = 'SS'; Theme = 'Supernatural, Horror' }
    "JP''s Metallica Pro (Stern 2013)"                                                           = @{ IPDBNum = 6028; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "JP''s Motor Show (Original 2017)"                                                           = @{ IPDBNum = 3631; Players = 4; Type = 'SS'; Theme = 'Monster Truck Rally, Motorcycles' }
    "JP''s Nascar Race (Original 2015)"                                                          = @{ IPDBNum = 5093; Players = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme' }
    "JP''s Papa Smurf (Original 2015)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "JP''s Pokemon Pinball (Original 2016)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cartoon, Kids, Video Game' }
    "JP''s Seawitch (Stern 1980)"                                                                = @{ IPDBNum = 2089; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "JP''s Smurfette (Original 2015)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation, Kids' }
    "JP''s Space Cadet - Family Edition (Original 2021)"                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Video Game' }
    "JP''s Space Cadet - Galaxy Edition (Original 2021)"                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Video Game' }
    "JP''s Space Cadet (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Video Game' }
    "JP''s Spider-Man (Original 2018)"                                                           = @{ IPDBNum = 5237; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes' }
    "JP''s Star Trek (Enterprise Limited Edition) (Original 2020)"                               = @{ IPDBNum = 6045; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie' }
    "JP''s Street Fighter II (Original 2016)"                                                    = @{ IPDBNum = 2403; Players = 4; Type = 'SS'; Theme = 'Martial Arts, Video Game' }
    "JP''s Terminator 2 (Original 2020)"                                                         = @{ IPDBNum = 2524; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Apocalyptic, Movie' }
    "JP''s Terminator 3 (Stern 2003)"                                                            = @{ IPDBNum = 4787; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie, Apocalyptic' }
    "JP''s The Avengers (Original 2019)"                                                         = @{ IPDBNum = 5938; Players = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes' }
    "JP''s The Lord of the Rings (Stern 2003)"                                                   = @{ IPDBNum = 4858; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie' }
    "JP''s The Lost World Jurassic Park (Original 2020)"                                         = @{ IPDBNum = 4136; Players = 6; Type = 'SS'; Theme = 'Dinosaurs, Movie, Licensed Theme' }
    "JP''s The Walking Dead (Original 2021)"                                                     = @{ IPDBNum = 6155; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Supernatural, Zombies, TV Show' }
    "JP''s Transformers (Original 2018)"                                                         = @{ IPDBNum = 5709; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie' }
    "JP''s VPX Arcade Physics (Original 2022)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Educational, Testing, Physics' }
    "JP''s Whoa Nellie! Big Juicy Melons (Original 2022)"                                        = @{ IPDBNum = 5863; Players = 1; Type = 'EM'; Theme = 'Agriculture, Fantasy, Women' }
    "JP''s World Joker Tour - nFozzy Mod (Original 2024)"                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Poker, Comics' }
    "JP''s World Joker Tour (Original 2024)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Poker, Comics' }
    "JP''s WOW Monopoly (Original 2015)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Board Games, Video Game' }
    "JP''s Wrath of Olympus (Original 2022)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Mythology' }
    "Jubilee (Williams 1973)"                                                                    = @{ IPDBNum = 1321; Players = 4; Type = 'EM'; Theme = 'Historical' }
    "Judas Priest (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Judas Priest (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Judge Dredd (Bally 1993)"                                                                   = @{ IPDBNum = 1322; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes' }
    "Jukebox (Seeburg 1965)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'PM'; Theme = 'Music, Jukebox' }
    "Jumanji (Original 2023)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Adventure, Fantasy' }
    "Jumping Jack (Gottlieb 1973)"                                                               = @{ IPDBNum = 1329; Players = 2; Type = 'EM'; Theme = 'Circus, Carnival' }
    "Jungle (Gottlieb 1972)"                                                                     = @{ IPDBNum = 1332; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Jungle King (Gottlieb 1973)"                                                                = @{ IPDBNum = 1336; Players = 1; Type = 'EM'; Theme = 'Jungle' }
    "Jungle Life (Gottlieb 1972)"                                                                = @{ IPDBNum = 1337; Players = 1; Type = 'EM'; Theme = 'Jungle' }
    "Jungle Lord (Williams 1981)"                                                                = @{ IPDBNum = 1338; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Jungle Princess (Gottlieb 1977)"                                                            = @{ IPDBNum = 1339; Players = 2; Type = 'EM'; Theme = 'Fantasy' }
    "Jungle Queen (Gottlieb 1977)"                                                               = @{ IPDBNum = 1340; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Jungle Quest (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Jungle' }
    "Junk Yard (Williams 1996)"                                                                  = @{ IPDBNum = 4014; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Junkyard Cats (Original 2012)"                                                              = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Apocalyptic, Science Fiction' }
    "Jurassic Park (Data East 1993)"                                                             = @{ IPDBNum = 1343; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Dinosaurs' }
    "Jurassic Park (Original 2022)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Dinosaurs' }
    "Jurassic Park 30th Anniversary (Original 2023)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Dinosaurs, Fantasy' }
    "Justin Timberlake (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Kat & Roman Kostrzewski - PuP-Pack Edition (Original 2023)"                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Rock' }
    "Kat & Roman Kostrzewski (Original 2023)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Rock' }
    "Kessel Run (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = '' }
    "Kick Off (Bally 1977)"                                                                      = @{ IPDBNum = 1365; Players = 4; Type = 'EM'; Theme = 'Sports, Soccer' }
    "Kickoff (Williams 1967)"                                                                    = @{ IPDBNum = 1362; Players = 1; Type = 'EM'; Theme = 'Sports, American Football' }
    "Kidnap (CIC Play 1986)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy' }
    "Kill Bill (Original 2022)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Killer Instinct (Original 2024)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Martial Arts' }
    "Killer Klowns (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Killers Hall of Fame (Original 2023)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror' }
    "Killswitch Engine (Original 2025)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Killzone (Original 2019)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Kim Wilde (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Kim Wilde (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "King Donkey Kong (Original 2023)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "King Kong (Data East 1990)"                                                                 = @{ IPDBNum = 3194; Players = 4; Type = 'SS'; Theme = 'Fantasy, Monsters, Licensed Theme, Movie' }
    "King Kong (LTD do Brasil 1978)"                                                             = @{ IPDBNum = 5894; Players = 2; Type = 'SS'; Theme = 'Fantasy, Monsters' }
    "King Kool (Gottlieb 1972)"                                                                  = @{ IPDBNum = 1371; Players = 2; Type = 'EM'; Theme = 'Happiness, Music' }
    "King of Diamonds (Gottlieb 1967)"                                                           = @{ IPDBNum = 1372; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "King of Rock and Roll (Original 2022)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "King Of The Hill (Original 2025)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Animation' }
    "King Pin (Gottlieb 1973)"                                                                   = @{ IPDBNum = 1374; Players = 1; Type = 'EM'; Theme = 'Sports, Bowling' }
    "King Pin (Williams 1962)"                                                                   = @{ IPDBNum = 1375; Players = 1; Type = 'EM'; Theme = 'Sports, Bowling' }
    "King Rock (Gottlieb 1972)"                                                                  = @{ IPDBNum = 1377; Players = 4; Type = 'EM'; Theme = 'Happiness, Music' }
    "King Tut (Bally 1969)"                                                                      = @{ IPDBNum = 1378; Players = 1; Type = 'EM'; Theme = 'Egyptology, Historical' }
    "King Tut (Williams 1979)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling' }
    "Kingdom (J. Esteban 1980)"                                                                  = @{ IPDBNum = 5168; Players = 4; Type = 'EM'; Theme = 'Myth and Legend' }
    "Kingdom Planets (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Space Fantasy, Anime' }
    "Kingpin (Capcom 1996)"                                                                      = @{ IPDBNum = 4000; Players = 4; Type = 'SS'; Theme = 'Police, Mobsters, Crime' }
    "Kings & Queens (Gottlieb 1965)"                                                             = @{ IPDBNum = 1381; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Kings of Steel (Bally 1984)"                                                                = @{ IPDBNum = 1382; Players = 4; Type = 'SS'; Theme = 'Historical, Knights, Cards' }
    "KISS - PuP-Pack Edition (Bally 1979)"                                                       = @{ IPDBNum = 1386; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music' }
    "KISS (Bally 1979)"                                                                          = @{ IPDBNum = 1386; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed, Music' }
    "KISS (Pro) - PuP-Pack Edition (Stern 2015)"                                                 = @{ IPDBNum = 6267; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Celebrities, Music' }
    "KISS (Pro) (Stern 2015)"                                                                    = @{ IPDBNum = 6267; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Celebrities, Music' }
    "Klondike (Williams 1971)"                                                                   = @{ IPDBNum = 1388; Players = 1; Type = 'EM'; Theme = 'Canadian West' }
    "Knight Rider (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Knock Out (Gottlieb 1950)"                                                                  = @{ IPDBNum = 1391; Players = 1; Type = 'EM'; Theme = 'Sports, Boxing' }
    "Kong vs. Godzilla (Original 2023)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Fantasy, Monsters' }
    "Kratos - God of War (Original 2018)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Video Game' }
    "Krull (Gottlieb 1983)"                                                                      = @{ IPDBNum = 1397; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie' }
    "Kung Fu (LTD do Brasil 1975)"                                                               = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Martial Arts' }
    "Kung Fu Hustle (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Kung Fu' }
    "Kusogrande (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Kyrie (Original 2025)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Anime, Kids' }
    "Lab, The (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = '' }
    "Labyrinth (Original 2021)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Fantasy' }
    "Labyrinth (Original 2023)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Fantasy' }
    "Lady Death (Geiger 1983)"                                                                   = @{ IPDBNum = 3972; Players = 4; Type = 'SS'; Theme = 'Fantasy, Vampires' }
    "Lady Luck (Bally 1986)"                                                                     = @{ IPDBNum = 1402; Players = 4; Type = 'SS'; Theme = 'Gambling, Cards, Poker' }
    "Lady Luck (Recel 1976)"                                                                     = @{ IPDBNum = 1405; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Lady Luck (Taito do Brasil 1980)"                                                           = @{ IPDBNum = 5010; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "Lagerstein (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Drinking' }
    "Lap by Lap (Inder 1986)"                                                                    = @{ IPDBNum = 4098; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Lariat (Gottlieb 1969)"                                                                     = @{ IPDBNum = 1412; Players = 2; Type = 'EM'; Theme = 'American West' }
    "Laser Ball (Williams 1979)"                                                                 = @{ IPDBNum = 1413; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Laser Cue (Williams 1984)"                                                                  = @{ IPDBNum = 1414; Players = 4; Type = 'SS'; Theme = 'Billiards, Outer Space, Fantasy' }
    "Laser War (Data East 1987)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Last Action Hero (Data East 1993)"                                                          = @{ IPDBNum = 1416; Players = 4; Type = 'SS'; Theme = 'Fictional, Licensed Theme, Movie' }
    "Last Dragon, The (Original 2020)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Martial Arts' }
    "Last Dragon, The (Original 2025)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Martial Arts' }
    "Last Lap (Playmatic 1978)"                                                                  = @{ IPDBNum = 3207; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Last Ninja, The (Original 2018)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Martial Arts' }
    "Last of Us, The (Original 2018)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, TV Show' }
    "Last Spaceship - Murray Leinster, The (Original 2024)"                                      = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction' }
    "Last Starfighter, The (Original 2020)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Last Starfighter, The (Original 2023)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Last Unicorn, The (Original 2020)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Fantasy, Movie' }
    "Lawman (Gottlieb 1971)"                                                                     = @{ IPDBNum = 1419; Players = 2; Type = 'EM'; Theme = 'American West, Law Enforcement' }
    "Lazer Lord (Stern 1982)"                                                                    = @{ IPDBNum = 1421; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "League Champ (Williams 1996)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling' }
    "Lectronamo (Stern 1978)"                                                                    = @{ IPDBNum = 1429; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Led Zeppelin (Original 2017)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Led Zeppelin (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Legend - A Pinball Adventure (Original 2023)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Fantasy' }
    "Legend of Zelda, The (Original 2015)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Legends of Valhalla (Original 2021)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy' }
    "Legends of Wrestlemania (Limited Edition) (Original 2023)"                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Wrestling' }
    "LEGO Pinball (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Toy Franchise, Superheroes' }
    "Lenny Kravitz (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock, Soul' }
    "Leprechaun King, The (Original 2019)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Les Mystérieuses Cités d''or (Original 2022)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Lethal Weapon 3 (Data East 1992)"                                                           = @{ IPDBNum = 1433; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Police, Crime, Action, Movie' }
    "Liberty Bell (Williams 1977)"                                                               = @{ IPDBNum = 1436; Players = 2; Type = 'EM'; Theme = 'American History, Historical' }
    "Life Is But a Dream - Avenged Sevenfold (Original 2024)"                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Lightning (Stern 1981)"                                                                     = @{ IPDBNum = 1441; Players = 4; Type = 'SS'; Theme = 'Fantasy, Norse Mythology' }
    "Lightning Ball (Gottlieb 1959)"                                                             = @{ IPDBNum = 1442; Players = 1; Type = 'EM'; Theme = 'Dancing, Party' }
    "Lights...Camera...Action! (Gottlieb 1989)"                                                  = @{ IPDBNum = 1445; Players = 4; Type = 'SS'; Theme = 'Movie, Show Business' }
    "Lilo & Stitch (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Kids, Animation' }
    "Line Drive (Williams 1972)"                                                                 = @{ IPDBNum = 1447; Players = 2; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Linkin Park (Original 2020)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Linkin Park (Original 2024)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Little Chief (Williams 1975)"                                                               = @{ IPDBNum = 1458; Players = 4; Type = 'EM'; Theme = 'American West, Native Americans' }
    "Little Joe (Bally 1972)"                                                                    = @{ IPDBNum = 1460; Players = 4; Type = 'EM'; Theme = 'Playing Dice, Games' }
    "Loch Ness Monster (Game Plan 1985)"                                                         = @{ IPDBNum = 1465; Players = 4; Type = 'SS'; Theme = 'Monsters' }
    "Locomotion (Zaccaria 1981)"                                                                 = @{ IPDBNum = 3217; Players = 4; Type = 'SS'; Theme = 'Travel, Railroad' }
    "Logan''s Run (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Lone Wolf McQuade (Original 2020)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Looney Tunes (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Loony Labyrinth (Original 2024)"                                                            = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Video Game' }
    "Lord of the Rings - The Rings of Power, The (Original 2022)"                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Fantasy' }
    "Lord of the Rings, The - Valinor Edition (Stern 2003)"                                      = @{ IPDBNum = 4858; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Wizards' }
    "Lord of the Rings, The (Stern 2003)"                                                        = @{ IPDBNum = 4858; Players = 4; Type = 'SS'; Theme = 'Fantasy, Licensed Theme, Movie, Wizards' }
    "Lortium (Juegos Populares 1987)"                                                            = @{ IPDBNum = 4104; Players = 4; Type = 'SS'; Theme = 'Space Fantasy' }
    "Lost Boys, The (Original 2025)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror, Vampires' }
    "Lost in Space (Sega 1998)"                                                                  = @{ IPDBNum = 4442; Players = 6; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, TV Show, Robots, Science Fiction, Movie' }
    "Lost World (Bally 1978)"                                                                    = @{ IPDBNum = 1476; Players = 4; Type = 'SS'; Theme = 'Fantasy, Dinosaurs' }
    "Lost World Jurassic Park, The (Sega 1997)"                                                  = @{ IPDBNum = 4136; Players = 6; Type = 'SS'; Theme = 'Dinosaurs, Licensed Theme, Movie' }
    "Louis de Funes - Fantomas (Original 2022)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Celebrities, Tribute' }
    "Love Bug (Williams 1971)"                                                                   = @{ IPDBNum = 1480; Players = 1; Type = 'EM'; Theme = 'Dancing, Happiness, Music' }
    "Luck Smile - 4 Player Edition (Inder 1976)"                                                 = @{ IPDBNum = 3886; Players = 4; Type = 'EM'; Theme = 'Gambling' }
    "Luck Smile (Inder 1976)"                                                                    = @{ IPDBNum = 3886; Players = 4; Type = 'EM'; Theme = 'Gambling' }
    "Lucky Ace (Williams 1974)"                                                                  = @{ IPDBNum = 1483; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Lucky Hand (Gottlieb 1977)"                                                                 = @{ IPDBNum = 1488; Players = 1; Type = 'EM'; Theme = 'Gambling, Cards' }
    "Lucky Luke (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'American West' }
    "Lucky Seven (Williams 1978)"                                                                = @{ IPDBNum = 1491; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "Lucky Strike (Gottlieb 1975)"                                                               = @{ IPDBNum = 1497; Players = 1; Type = 'EM'; Theme = 'American West, Prospecting' }
    "Lucky Strike (Taito do Brasil 1978)"                                                        = @{ IPDBNum = 5492; Players = 4; Type = 'EM'; Theme = 'Sports, Bowling' }
    "Lunar Howl (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Rock, Kids, Anime' }
    "Lunelle (Taito do Brasil 1981)"                                                             = @{ IPDBNum = 4591; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Mac Jungle (MAC 1987)"                                                                      = @{ IPDBNum = 3187; Players = 4; Type = 'SS'; Theme = 'Fantasy, Jungle' }
    "Mac''s Galaxy (MAC 1986)"                                                                   = @{ IPDBNum = 3455; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy' }
    "Mach 2.0 Two (Spinball S.A.L. 1995)"                                                        = @{ IPDBNum = 4617; Players = 4; Type = 'SS'; Theme = 'Aviation' }
    "Machine - Bride of Pin-bot, The (Williams 1991)"                                            = @{ IPDBNum = 1502; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Robots' }
    "Mad Max - Fury Road (Original 2021)"                                                        = @{ IPDBNum = 0; Players = 6; Type = 'SS'; Theme = 'Movie, Apocalyptic' }
    "Mad Max 2 - The Road Warrior (Original 2019)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Apocalyptic' }
    "Mad Race (Playmatic 1985)"                                                                  = @{ IPDBNum = 3445; Players = 4; Type = 'SS'; Theme = 'Motorcycle Racing' }
    "Mad Scientist (Maxis 1996)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction' }
    "Magic - The Gathering (Original 2020)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Magic (Stern 1979)"                                                                         = @{ IPDBNum = 1509; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Magic Castle (Zaccaria 1984)"                                                               = @{ IPDBNum = 1511; Players = 4; Type = 'SS'; Theme = 'Fantasy, Vampires' }
    "Magic Circle (Bally 1965)"                                                                  = @{ IPDBNum = 1513; Players = 1; Type = 'EM'; Theme = 'Fortune Telling, Dancing, Music' }
    "Magic City (Williams 1967)"                                                                 = @{ IPDBNum = 1514; Players = 0; Type = 'EM'; Theme = 'American Places' }
    "Magic Clock (Williams 1960)"                                                                = @{ IPDBNum = 1515; Players = 2; Type = 'EM'; Theme = 'Dancing, Outdoor Activities' }
    "Magic Pinball (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Magic' }
    "Magic Town (Williams 1967)"                                                                 = @{ IPDBNum = 1518; Players = 0; Type = 'EM'; Theme = 'American Places' }
    "Magnificent Seven, The (Original 2020)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'American West, Movie' }
    "Magnotron (Gottlieb 1974)"                                                                  = @{ IPDBNum = 1519; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Magnum P.I.nBall (Original 2020)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Mago de Oz (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Major League (PAMCO 1934)"                                                                  = @{ IPDBNum = 5497; Players = 0; Type = 'EM'; Theme = 'Sports, Baseball, Flipperless' }
    "Major Payne (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Movie' }
    "Mandalorian, The - Razor Crest (Original 2023)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction, Space Fantasy, TV Show' }
    "Mandalorian, The (Original 2020)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy, TV Show' }
    "Mandalorian, The (Original 2023)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction, Space Fantasy, TV Show' }
    "Manowar (Original 2019)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Manowar (Original 2021)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Maple Leaf, The (Automatic 1932)"                                                           = @{ IPDBNum = 5321; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Marble Queen (Gottlieb 1953)"                                                               = @{ IPDBNum = 1541; Players = 1; Type = 'EM'; Theme = 'Playing Marbles' }
    "Marilyn Manson (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music, Heavy Metal' }
    "Marilyn Monroe Tribute (Original 2022)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Celebrities' }
    "Mariner (Bally 1971)"                                                                       = @{ IPDBNum = 1546; Players = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Fishing, Scuba Diving' }
    "Mario Andretti (Gottlieb 1995)"                                                             = @{ IPDBNum = 3793; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Mario Kart Pinball (Original 2022)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Kart Racing, Video Game, Kids' }
    "Maroon 5 (Original 2021)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Married with Children (Original 2021)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Comedy' }
    "Mars Attacks! Pinball (Original 2022)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Aliens, Martians, Fantasy' }
    "Mars God of War (Gottlieb 1981)"                                                            = @{ IPDBNum = 1549; Players = 4; Type = 'SS'; Theme = 'Mythology' }
    "Mars Trek (Sonic 1977)"                                                                     = @{ IPDBNum = 1550; Players = 0; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Marsupilami (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Kids' }
    "Martian Queen (LTD do Brasil 1981)"                                                         = @{ IPDBNum = 5885; Players = 0; Type = 'SS'; Theme = 'Aliens, Martians, Fantasy, Outer Space' }
    "Mary Shelley''s Frankenstein - B&W Edition (Sega 1995)"                                     = @{ IPDBNum = 947; Players = 4; Type = 'SS'; Theme = 'Fictional, Horror' }
    "Mary Shelley''s Frankenstein (Sega 1995)"                                                   = @{ IPDBNum = 947; Players = 4; Type = 'SS'; Theme = 'Fictional, Horror' }
    "Mask (Original 2023)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cartoon, Animation' }
    "Mask, The (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Superheroes, Comedy, Fantasy' }
    "Masquerade (Gottlieb 1966)"                                                                 = @{ IPDBNum = 1553; Players = 4; Type = 'EM'; Theme = 'Happiness, Dancing' }
    "Masters of the Universe (Original 2018)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, TV Show' }
    "Masters of the Universe (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, TV Show' }
    "Mata Hari (Bally 1978)"                                                                     = @{ IPDBNum = 4501; Players = 4; Type = 'SS'; Theme = 'Historical, Espionage' }
    "Matrix, The (Original 2023)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Maverick (Data East 1994)"                                                                  = @{ IPDBNum = 1561; Players = 0; Type = 'SS'; Theme = 'Cards, Gambling, Celebrities, Fictional, Licensed Theme, American West, Movie' }
    "Meat Loaf (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 2025; Type = 'SS'; Theme = 'Music' }
    "Medieval Castle (Original 2006)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Medieval' }
    "Medieval Madness - B&W Edition (Williams 1997)"                                             = @{ IPDBNum = 4032; Players = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons' }
    "Medieval Madness - Redux Edition (Williams 1997)"                                           = @{ IPDBNum = 4032; Players = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons' }
    "Medieval Madness - Remake Edition (Williams 1997)"                                          = @{ IPDBNum = 4032; Players = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons' }
    "Medieval Madness (Williams 1997)"                                                           = @{ IPDBNum = 4032; Players = 4; Type = 'SS'; Theme = 'Fantasy, Medieval, Wizards, Magic, Dragons' }
    "Meducks (Original 2024)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Animation, Kids' }
    "Medusa (Bally 1981)"                                                                        = @{ IPDBNum = 1565; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "Mega Man (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Megadeth (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Melody (Gottlieb 1967)"                                                                     = @{ IPDBNum = 1566; Players = 1; Type = 'EM'; Theme = 'Music, Singing' }
    "Memory Lane (Stern 1978)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Bowling' }
    "Men in Black Trilogy (Original 2024)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Mermaid (Gottlieb 1951)"                                                                    = @{ IPDBNum = 1574; Players = 1; Type = 'EM'; Theme = 'Fishing, Sports' }
    "Merry-Go-Round (Gottlieb 1960)"                                                             = @{ IPDBNum = 1578; Players = 2; Type = 'EM'; Theme = 'Amusement Park' }
    "Metal Man (Inder 1992)"                                                                     = @{ IPDBNum = 4092; Players = 0; Type = 'SS'; Theme = 'Fantasy' }
    "Metal Slug (Original 2017)"                                                                 = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Video Game' }
    "Metallica - Master of Puppets (Original 2020)"                                              = @{ IPDBNum = 6030; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Metallica (Premium Monsters) - Christmas Edition (Stern 2013)"                              = @{ IPDBNum = 6030; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Heavy Metal' }
    "Metallica (Premium Monsters) (Stern 2013)"                                                  = @{ IPDBNum = 6030; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Heavy Metal' }
    "Meteor (Stern 1979)"                                                                        = @{ IPDBNum = 1580; Players = 4; Type = 'SS'; Theme = 'Outer Space, Licensed Theme' }
    "Meteor (Taito do Brasil 1979)"                                                              = @{ IPDBNum = 4571; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Metropolis (Maresa 1982)"                                                                   = @{ IPDBNum = 5732; Players = 0; Type = 'EM'; Theme = 'Fantasy, Outer Space, Science Fiction' }
    "Metropolis Reborn (Original 2022)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Mets (Original 2023)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Baseball' }
    "MF Doom (Original 2024)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Rap, Music' }
    "Miami Vice (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Mibs (Gottlieb 1969)"                                                                       = @{ IPDBNum = 1589; Players = 1; Type = 'EM'; Theme = 'Playing Marbles' }
    "Michael Jackson (Original 2020)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Michael Jordan - Black Cat Edition (Data East 1992)"                                        = @{ IPDBNum = 3425; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball' }
    "Michael Jordan (Data East 1992)"                                                            = @{ IPDBNum = 3425; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball' }
    "Mickey Mouse Happy Christmas (Original 2022)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Christmas, Animation, Kids' }
    "Mickey Mouse Happy Halloween (Original 2022)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Halloween, Animation, Kids' }
    "Mickey Mouse in Steamboat Willie (Original 2022)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Middle Earth (Atari 1978)"                                                                  = @{ IPDBNum = 1590; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Midget Hi-Ball (Peo 1932)"                                                                  = @{ IPDBNum = 4657; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Midnight Magic (Atari 1986)"                                                                = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Video Game' }
    "Midnight Resistance (Original 2020)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Mighty Morphin Power Rangers (Original 2024)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Superheroes, TV Show, Kids' }
    "Mike Vegas (Original 2023)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Las Vegas, Gambling' }
    "Mike''s Pinball - 10th Anniversary Edition (Original 2024)"                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = '' }
    "Millionaire (Williams 1987)"                                                                = @{ IPDBNum = 1597; Players = 4; Type = 'SS'; Theme = 'Affluence, Money' }
    "Minecraft (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Mini Cycle (Gottlieb 1970)"                                                                 = @{ IPDBNum = 1604; Players = 2; Type = 'EM'; Theme = 'Motorcycles' }
    "Mini Golf (Williams 1964)"                                                                  = @{ IPDBNum = 3434; Players = 2; Type = 'EM'; Theme = 'Sports, Golf' }
    "Mini Pool (Gottlieb 1969)"                                                                  = @{ IPDBNum = 1605; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Mini-Baseball (Chicago Coin 1972)"                                                          = @{ IPDBNum = 5985; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball, Flipperless' }
    "Minions (Original 2017)"                                                                    = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Movie, Animation, Kids' }
    "Miraculous (Original 2019)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Movie, Animation, Kids' }
    "Misfits (Original 2019)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Miss World (Geiger 1982)"                                                                   = @{ IPDBNum = 3970; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Miss-O (Williams 1969)"                                                                     = @{ IPDBNum = 1612; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Missing in Action (Original 2018)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Mission Impossible (Original 2022)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Mississippi (Recreativos Franco 1973)"                                                      = @{ IPDBNum = 5955; Players = 1; Type = 'EM'; Theme = 'American Places, Cards, Gambling' }
    "Mobile Suit Gundam (Original 2024)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Anime, Science Fiction' }
    "Moebius - A Tribute (Original 2024)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Tribute' }
    "Monaco (Segasa 1977)"                                                                       = @{ IPDBNum = 1614; Players = 0; Type = 'EM'; Theme = 'World Places, Sports, Happiness, Recreation, Water Skiing, Swimming, Aquatic' }
    "Monday Night Football (Data East 1989)"                                                     = @{ IPDBNum = 1616; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "Monopoly (Stern 2001)"                                                                      = @{ IPDBNum = 4505; Players = 4; Type = 'SS'; Theme = 'Board Games, Licensed Theme' }
    "Monster Bash (Williams 1998)"                                                               = @{ IPDBNum = 4441; Players = 4; Type = 'SS'; Theme = 'Horror, Licensed Theme' }
    "Monster Rancher (Original 2019)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Monsters' }
    "Monsters (Original 2016)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Monsters' }
    "Monsters of Rock (Original 2021)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Monte Carlo (Bally 1973)"                                                                   = @{ IPDBNum = 1621; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Monte Carlo (Gottlieb 1987)"                                                                = @{ IPDBNum = 1622; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "Monty Python (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Comedy' }
    "Moon Light (Inder 1987)"                                                                    = @{ IPDBNum = 4416; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Moon Shot (Chicago Coin 1969)"                                                              = @{ IPDBNum = 1628; Players = 0; Type = 'EM'; Theme = 'Outer Space' }
    "Moon Station (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction' }
    "Moon Walking Dead, The (Original 2017)"                                                     = @{ IPDBNum = 6156; Players = 4; Type = 'SS'; Theme = 'Supernatural, Zombies' }
    "Mortal Kombat (Original 2016)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Martial Arts' }
    "Mortal Kombat II (Original 2016)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Martial Arts' }
    "Motley Crue - Carnival of Sin (Original 2024)"                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Motley Crue (Original 2017)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Motordome (Bally 1986)"                                                                     = @{ IPDBNum = 1633; Players = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross' }
    "Motörhead (Original 2018)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Moulin Rouge (Williams 1965)"                                                               = @{ IPDBNum = 1634; Players = 1; Type = 'EM'; Theme = 'Adventure, Foreign Peoples' }
    "Mousin'' Around! (Bally 1989)"                                                              = @{ IPDBNum = 1635; Players = 4; Type = 'SS'; Theme = 'Adventure' }
    "Mr. & Mrs. Pac-Man Pinball (Bally 1982)"                                                    = @{ IPDBNum = 1639; Players = 4; Type = 'SS'; Theme = 'Happiness, Video Game' }
    "Mr. & Mrs. Pec-Men (LTD do Brasil 1983)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Happiness, Video Game' }
    "Mr. Big (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Mr. Black (Taito do Brasil 1984)"                                                           = @{ IPDBNum = 4586; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Mr. Bubble (Original 2018)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = '' }
    "Mr. Doom (Recel 1979)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror' }
    "Mr. Evil (Recel 1978)"                                                                      = @{ IPDBNum = 1638; Players = 1; Type = 'EM'; Theme = 'Fictional Characters, Mythology, Horror' }
    "Mundial 90 (Inder 1990)"                                                                    = @{ IPDBNum = 4094; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Munsters, The (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Munsters, The (Original 2021)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Horror, Comedy' }
    "Muppets (Original 2022)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Mustang (Gottlieb 1977)"                                                                    = @{ IPDBNum = 1645; Players = 2; Type = 'EM'; Theme = 'American West' }
    "Mustang (Limited Edition) (Stern 2014)"                                                     = @{ IPDBNum = 6100; Players = 4; Type = 'SS'; Theme = 'Cars, Travel, Licensed Theme' }
    "Mystery Castle (Alvin G. 1993)"                                                             = @{ IPDBNum = 1647; Players = 4; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Mystery Science Theater 3000 - Pinball Peril (Original 2021)"                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Mystic (Bally 1980)"                                                                        = @{ IPDBNum = 1650; Players = 4; Type = 'SS'; Theme = 'Circus, Carnival, Magic' }
    "Mystical Ninja Goemon (Original 2025)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Ninja, Video Game, Anime, Kids' }
    "Nagatoro (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Nags (Williams 1960)"                                                                       = @{ IPDBNum = 1654; Players = 1; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Nairobi (Maresa 1966)"                                                                      = @{ IPDBNum = 6229; Players = 1; Type = 'EM'; Theme = 'Hunting, Safari, World Places' }
    "Namkwah (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Naruto Pinball (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "NASCAR - Dale Jr. (Stern 2005)"                                                             = @{ IPDBNum = 5093; Players = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme' }
    "NASCAR - Grand Prix (Stern 2005)"                                                           = @{ IPDBNum = 5093; Players = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme' }
    "NASCAR (Stern 2005)"                                                                        = @{ IPDBNum = 5093; Players = 4; Type = 'SS'; Theme = 'NASCAR, Auto Racing, Cars, Licensed Theme' }
    "National Lampoon''s Christmas Vacation (Original 2019)"                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie' }
    "Nautilus (Playmatic 1984)"                                                                  = @{ IPDBNum = 822; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "NBA (Stern 2009)"                                                                           = @{ IPDBNum = 5442; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball, Licensed' }
    "NBA Chicago Bulls (Original 2022)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Sports, Basketball' }
    "NBA Fastbreak (Bally 1997)"                                                                 = @{ IPDBNum = 4023; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball, Licensed' }
    "NBA Mac (MAC 1986)"                                                                         = @{ IPDBNum = 4606; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball' }
    "Near Dark (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror' }
    "Nebulon (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Robots, Science Fiction' }
    "Nebulon 2 - Humanity''s Stand (Original 2025)"                                              = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Robots, Science Fiction' }
    "Nebulon 3 - The Final Boss (Original 2025)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Science Fiction' }
    "Need for Speed (Original 2018)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cars, Video Game, Auto Racing' }
    "Nemesis (Peyper 1986)"                                                                      = @{ IPDBNum = 4880; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Neptune (Gottlieb 1978)"                                                                    = @{ IPDBNum = 1662; Players = 1; Type = 'EM'; Theme = 'Mythology' }
    "NeverEnding Story, The (Original 2021)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Fantasy, Kids' }
    "Nevermind The Bollocks (Original 2024)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "New Wave (Bell Games 1985)"                                                                 = @{ IPDBNum = 3482; Players = 4; Type = 'SS'; Theme = 'Music' }
    "New World (Playmatic 1976)"                                                                 = @{ IPDBNum = 1672; Players = 4; Type = 'EM'; Theme = 'Historical' }
    "New York (Gottlieb 1976)"                                                                   = @{ IPDBNum = 1673; Players = 2; Type = 'EM'; Theme = 'American Places, Historical' }
    "NFL - 49ers Edition (Stern 2001)"                                                           = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Bears Edition (Stern 2001)"                                                           = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Bengals Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Bills Edition (Stern 2001)"                                                           = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Broncos Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Browns Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Buccaneers Edition (Stern 2001)"                                                      = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Cardinals Edition (Stern 2001)"                                                       = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Chargers Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Chiefs Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Colts Edition (Stern 2001)"                                                           = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Commanders Edition (Stern 2001)"                                                      = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Cowboys Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Dolphins Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Eagles Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Falcons Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Giants Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Jaguars Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Jets Edition (Stern 2001)"                                                            = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Lions Edition (Stern 2001)"                                                           = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Packers Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Panthers Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Patriots Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Raiders Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Rams Edition (Stern 2001)"                                                            = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Ravens Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Redskins Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Saints Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Seahawks Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Steelers Edition (Stern 2001)"                                                        = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Texans Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Titans Edition (Stern 2001)"                                                          = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL - Vikings Edition (Stern 2001)"                                                         = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "NFL (Stern 2001)"                                                                           = @{ IPDBNum = 4540; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "Nickelback (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Night Moves (International Concepts 1989)"                                                  = @{ IPDBNum = 3507; Players = 4; Type = 'SS'; Theme = 'Adult, Nightlife' }
    "Night of the Living Dead ''68 (Original 2018)"                                              = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Horror' }
    "Night of the Living Dead (Pinventions 2014)"                                                = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Horror, Movie' }
    "Night Rider (Bally 1977)"                                                                   = @{ IPDBNum = 1677; Players = 4; Type = 'EM'; Theme = 'Travel, Transportation, Truck Driving' }
    "Nightmare (Digital Illusions 1992)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Horror' }
    "Nightmare Before Christmas (Original 2024)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Fantasy' }
    "Nightmare Before Christmas, The (Original 2019)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas' }
    "Nine Ball (Stern 1980)"                                                                     = @{ IPDBNum = 1678; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Nine Inch Nails (Original 2023)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music, Heavy Metal' }
    "Ninja Gaiden (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Ninja, Video Game' }
    "Nip-It (Bally 1973)"                                                                        = @{ IPDBNum = 1680; Players = 4; Type = 'EM'; Theme = 'Sports, Fishing, Aquatic' }
    "Nirvana (Original 2021)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Nitro Ground Shaker (Bally 1980)"                                                           = @{ IPDBNum = 1682; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "No Fear - Dangerous Sports (Williams 1995)"                                                 = @{ IPDBNum = 2852; Players = 4; Type = 'SS'; Theme = 'Sports, Licensed Theme, Motorcycles, Cars' }
    "No Good Gofers (Williams 1997)"                                                             = @{ IPDBNum = 4338; Players = 4; Type = 'SS'; Theme = 'Sports, Golf' }
    "NOBS (Original 2016)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cards' }
    "North Pole (Playmatic 1967)"                                                                = @{ IPDBNum = 6310; Players = 1; Type = 'EM'; Theme = 'World Places' }
    "North Star (Gottlieb 1964)"                                                                 = @{ IPDBNum = 1683; Players = 1; Type = 'EM'; Theme = 'World Places' }
    "Nosferatu 1922 (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Horror' }
    "Nova Pinball (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Pinball' }
    "Now (Gottlieb 1971)"                                                                        = @{ IPDBNum = 1685; Players = 4; Type = 'EM'; Theme = 'Psychedelic' }
    "Nudge Test and Calibration (Original 2017)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Testing, Calibration' }
    "Nudge-It (Gottlieb 1990)"                                                                   = @{ IPDBNum = 3454; Players = 1; Type = 'SS'; Theme = 'Prospecting' }
    "Nudgy (Bally 1947)"                                                                         = @{ IPDBNum = 1686; Players = 1; Type = 'EM'; Theme = 'Flipperless' }
    "Nugent (Stern 1978)"                                                                        = @{ IPDBNum = 1687; Players = 4; Type = 'SS'; Theme = 'Celebrities, Music' }
    "Nuka Cola - Pop-A-Top Pinball (Original 2024)"                                              = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = '' }
    "Nuke Em High (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Movie, Horror' }
    "O Brother, Where Art Thou (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Movie, Musical' }
    "O Gaucho (LTD do Brasil 1975)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'American West' }
    "Oasis Knebworth (Original 2023)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Celebrities' }
    "Oba-Oba (Taito do Brasil 1979)"                                                             = @{ IPDBNum = 4572; Players = 4; Type = 'SS'; Theme = 'Music, Dancing' }
    "Octopus (Nintendo 1981)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Flipperless' }
    "Odds & Evens - Bud Spencer & Terence Hill (Original 2021)"                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Movie' }
    "Odin Deluxe (Sonic 1985)"                                                                   = @{ IPDBNum = 3448; Players = 4; Type = 'SS'; Theme = 'Norse Mythology' }
    "Odisea Paris-Dakar (Peyper 1987)"                                                           = @{ IPDBNum = 4879; Players = 4; Type = 'SS'; Theme = 'Car Rally, Motorcycle Racing' }
    "Off Road Racers (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cars, Monster Truck Rally' }
    "Office, The (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Comedy' }
    "Ol'' Ireland (Original 2018)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'World Places' }
    "Old Chicago (Bally 1976)"                                                                   = @{ IPDBNum = 1704; Players = 4; Type = 'EM'; Theme = 'Historical, American Places' }
    "Old Coney Island! (Game Plan 1979)"                                                         = @{ IPDBNum = 553; Players = 4; Type = 'SS'; Theme = 'Happiness, Circus, Carnival' }
    "Old Tunes - Volume 1 (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon' }
    "Old Tunes - Volume 2 (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon' }
    "Old Tunes - Volume 3 (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon' }
    "Olympics (Chicago Coin 1975)"                                                               = @{ IPDBNum = 1711; Players = 2; Type = 'EM'; Theme = 'Sports, Olympic Games' }
    "Olympics (Gottlieb 1962)"                                                                   = @{ IPDBNum = 1714; Players = 1; Type = 'EM'; Theme = 'Olympic Games, Sports' }
    "Olympus (Juegos Populares 1986)"                                                            = @{ IPDBNum = 5140; Players = 4; Type = 'SS'; Theme = 'Mythology' }
    "On Beam (Bally 1969)"                                                                       = @{ IPDBNum = 1715; Players = 1; Type = 'EM'; Theme = 'Outer Space' }
    "Once Upon A Time In The West (Original 2019)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'American West, Movie' }
    "One Piece (Original 2023)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "One Punch Man Pinball (Original 2024)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime, Action' }
    "Op-Pop-Pop (Bally 1969)"                                                                    = @{ IPDBNum = 1722; Players = 1; Type = 'EM'; Theme = 'Psychedelic Art' }
    "Operation Highjump (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Science Fiction' }
    "Operation Thunder (Gottlieb 1992)"                                                          = @{ IPDBNum = 1721; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Orbit (Gottlieb 1971)"                                                                      = @{ IPDBNum = 1724; Players = 4; Type = 'EM'; Theme = 'Outer Space' }
    "Orbitor 1 (Stern 1982)"                                                                     = @{ IPDBNum = 1725; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Ouija (Original 2020)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Supernatural' }
    "Out of Sight (Gottlieb 1974)"                                                               = @{ IPDBNum = 1727; Players = 2; Type = 'EM'; Theme = 'Psychedelic' }
    "Outer Space (Gottlieb 1972)"                                                                = @{ IPDBNum = 1728; Players = 2; Type = 'EM'; Theme = 'Outer Space' }
    "OXO (Williams 1973)"                                                                        = @{ IPDBNum = 1733; Players = 4; Type = 'EM'; Theme = 'Board Games, Tic-Tac-Toe' }
    "Ozzy Osbourne (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Pabst Can Crusher, The (Stern 2016)"                                                        = @{ IPDBNum = 6335; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Drinking, Beer' }
    "PacMan (Original 2021)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Paddock (Williams 1969)"                                                                    = @{ IPDBNum = 1735; Players = 1; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Pain (Original 2024)"                                                                       = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Music' }
    "Pain (Original 2025)"                                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Palace Guard (Gottlieb 1968)"                                                               = @{ IPDBNum = 1737; Players = 1; Type = 'EM'; Theme = 'World Places, Historical' }
    "Pantera (Original 2020)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Panthera (Gottlieb 1980)"                                                                   = @{ IPDBNum = 1745; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Paolo NUTINI (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Paradise (Gottlieb 1965)"                                                                   = @{ IPDBNum = 1752; Players = 2; Type = 'EM'; Theme = 'Hawaii' }
    "Paragon (Bally 1979)"                                                                       = @{ IPDBNum = 1755; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Party Animal (Bally 1987)"                                                                  = @{ IPDBNum = 1763; Players = 4; Type = 'SS'; Theme = 'Happiness, Celebration' }
    "Party Zone, The (Bally 1991)"                                                               = @{ IPDBNum = 1764; Players = 4; Type = 'SS'; Theme = 'Happiness' }
    "Pat Hand (Williams 1975)"                                                                   = @{ IPDBNum = 1767; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Paul Bunyan (Gottlieb 1968)"                                                                = @{ IPDBNum = 1768; Players = 2; Type = 'EM'; Theme = 'Fantasy, Mythology' }
    "Paw Patrol, The (Original 2020)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, TV Show' }
    "PDC Darts 2023 (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Sports, Darts' }
    "PDC World Darts (Original 2020)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Darts' }
    "Peaky Blinders (Original 2021)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Pennant Fever (Williams 1984)"                                                              = @{ IPDBNum = 3335; Players = 2; Type = 'SS'; Theme = 'Sports, Baseball' }
    "Penthouse (Pinball Dreams 2008)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Adult' }
    "Peppa Pig Pinball (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Pepsi Man (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Drinking' }
    "Persona 5 Demo (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Pet Shop Boys Show (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Petaco (Juegos Populares 1984)"                                                             = @{ IPDBNum = 4883; Players = 0; Type = 'SS'; Theme = 'Music, People' }
    "Petaco 2 (Juegos Populares 1985)"                                                           = @{ IPDBNum = 5257; Players = 4; Type = 'SS'; Theme = 'Music, Singing, Dancing' }
    "Phantasm (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Phantogram  (Original 2018)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Phantom Haus (Williams 1996)"                                                               = @{ IPDBNum = 6840; Players = 1; Type = 'PM'; Theme = 'Haunted House' }
    "Phantom of the Opera (Data East 1990)"                                                      = @{ IPDBNum = 1777; Players = 4; Type = 'SS'; Theme = 'Music, Singing' }
    "Phantom of the Paradise (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Musical, Movie, Comedy, Horror' }
    "Pharaoh - Dead Rise (Original 2019)"                                                        = @{ IPDBNum = 1778; Players = 4; Type = 'SS'; Theme = 'Historical' }
    "Pharaoh (Williams 1981)"                                                                    = @{ IPDBNum = 1778; Players = 4; Type = 'SS'; Theme = 'Historical' }
    "Phase II (J. Esteban 1975)"                                                                 = @{ IPDBNum = 5787; Players = 0; Type = 'EM'; Theme = 'Mysticism' }
    "Phil Collins (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Phish (Original 2024)"                                                                      = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Music, Rock' }
    "Phoenix (Williams 1978)"                                                                    = @{ IPDBNum = 1780; Players = 0; Type = 'SS'; Theme = 'Mythology' }
    "Pierce The Veil (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Progressive, Rock' }
    "Piggy Bank Blitz (Original 2023)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Flipperless' }
    "Pin City (Original 2018)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Example' }
    "PIN-BOT (Williams 1986)"                                                                    = @{ IPDBNum = 1796; Players = 4; Type = 'SS'; Theme = 'Fantasy, Outer Space' }
    "Pin-Up (Gottlieb 1975)"                                                                     = @{ IPDBNum = 1789; Players = 1; Type = 'EM'; Theme = 'Sports, Bowling' }
    "Pinball (EM) (Stern 1977)"                                                                  = @{ IPDBNum = 1792; Players = 4; Type = 'SS'; Theme = 'Sports, Pinball' }
    "Pinball (SS) (Stern 1977)"                                                                  = @{ IPDBNum = 4694; Players = 4; Type = 'SS'; Theme = 'Pinball, Sports' }
    "Pinball Action (Tekhan 1985)"                                                               = @{ IPDBNum = 5252; Players = 2; Type = 'SS'; Theme = '' }
    "Pinball Champ ''82 (Zaccaria 1982)"                                                         = @{ IPDBNum = 1794; Players = 4; Type = 'SS'; Theme = 'Pinball' }
    "Pinball Domes (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Example' }
    "Pinball Food Fight, The (Original 2016)"                                                    = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "Pinball Lizard (Game Plan 1980)"                                                            = @{ IPDBNum = 1464; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Pinball Magic (Capcom 1995)"                                                                = @{ IPDBNum = 3596; Players = 4; Type = 'SS'; Theme = 'Show Business, Magic' }
    "Pinball Pool (Gottlieb 1979)"                                                               = @{ IPDBNum = 1795; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Pinball Solitaire (Original 2025)"                                                          = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Cards, Solitaire' }
    "Pinball Squared (Gottlieb 1984)"                                                            = @{ IPDBNum = 5341; Players = 4; Type = 'SS'; Theme = '' }
    "PinBlob (Original 2024)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror' }
    "Pindar - The Lizard King (Original 2021)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Monsters' }
    "Pink Bubble Monsters (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Children''s Games, Monsters, Water' }
    "Pink Floyd - The Wall (Original 2020)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Pink Floyd (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Pink Floyd Pinball (Original 2020)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Pink Panther (Gottlieb 1981)"                                                               = @{ IPDBNum = 1800; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional' }
    "Pink Wind Turbine (Original 2025)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Kids' }
    "Pinocchio (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Fairytale, Kids' }
    "PinUP JukeBox - The 80s (Original 2019)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Jukebox' }
    "Pioneer (Gottlieb 1976)"                                                                    = @{ IPDBNum = 1802; Players = 2; Type = 'EM'; Theme = 'American History' }
    "Pipeline (Gottlieb 1981)"                                                                   = @{ IPDBNum = 5327; Players = 4; Type = 'SS'; Theme = '' }
    "Pirate Gold (Chicago Coin 1969)"                                                            = @{ IPDBNum = 1804; Players = 1; Type = 'EM'; Theme = 'Pirates, Nautical, Treasure' }
    "Pirates Life - The Revenge of Cecil Hoggleston (Original 2024)"                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Pirates of the Caribbean (Stern 2006)"                                                      = @{ IPDBNum = 5163; Players = 4; Type = 'SS'; Theme = 'Pirates, Licensed Theme, Movie' }
    "Pistol Poker (Alvin G. 1993)"                                                               = @{ IPDBNum = 1805; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Pit Stop (Williams 1968)"                                                                   = @{ IPDBNum = 1806; Players = 2; Type = 'EM'; Theme = 'Sports, Auto Racing' }
    "Pizza Time (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Food' }
    "PJ Masks (Original 2020)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Planet Hemp - PuP-Pack Edition (Original 2025)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rap' }
    "Planet Hemp (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rap' }
    "Planet of the Apes (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Planets (Williams 1971)"                                                                    = @{ IPDBNum = 1811; Players = 2; Type = 'EM'; Theme = 'Astrology' }
    "Play Ball (Gremlin 1972)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'PM'; Theme = 'Baseball' }
    "Play Pool (Gottlieb 1972)"                                                                  = @{ IPDBNum = 1819; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Playball (Gottlieb 1971)"                                                                   = @{ IPDBNum = 1816; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "Playboy - Definitive Edition (Bally 1978)"                                                  = @{ IPDBNum = 1823; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Adult' }
    "Playboy (Bally 1978)"                                                                       = @{ IPDBNum = 1823; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Adult' }
    "Playboy (Stern 2002)"                                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Adult, Licensed Theme' }
    "Playboy 35th Anniversary (Data East 1989)"                                                  = @{ IPDBNum = 1822; Players = 0; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Adult' }
    "Playmate (Original 2020)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Adult' }
    "PlayMates (Gottlieb 1968)"                                                                  = @{ IPDBNum = 1828; Players = 1; Type = 'EM'; Theme = 'Happiness, Board Games, Dominoes' }
    "Poison (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock, Heavy Metal' }
    "Pokemon Mystery Dungeon (Original 2025)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon, Video Game, Kids' }
    "Pokemon Pinball (Original 2021)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon, Kids' }
    "Pokemon Slots (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Pokemon, Slotmachine' }
    "Pokerino (Williams 1978)"                                                                   = @{ IPDBNum = 1839; Players = 0; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Polar Explorer (Taito do Brasil 1983)"                                                      = @{ IPDBNum = 4588; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Polar Express, The (Original 2018)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Animation, Kids' }
    "Pole Position (Sonic 1987)"                                                                 = @{ IPDBNum = 3322; Players = 4; Type = 'SS'; Theme = 'Cars, Auto Racing' }
    "Police Academy (Original 2019)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Movie, Comedy, Police' }
    "Police Force (Williams 1989)"                                                               = @{ IPDBNum = 1841; Players = 0; Type = 'SS'; Theme = 'Police, Crime' }
    "Police, The (Original 2024)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Polo (Gottlieb 1970)"                                                                       = @{ IPDBNum = 1843; Players = 4; Type = 'EM'; Theme = 'Sports, Polo' }
    "Polo Skill (A. Pirmischer 1931)"                                                            = @{ IPDBNum = 0; Players = 1; Type = 'PM'; Theme = 'Polo, Flipperless' }
    "Poltergeist (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Pompeii (Williams 1978)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling' }
    "Pool Sharks (Bally 1990)"                                                                   = @{ IPDBNum = 1848; Players = 4; Type = 'SS'; Theme = 'Sports, Billiards' }
    "Pop-A-Card (Gottlieb 1972)"                                                                 = @{ IPDBNum = 1849; Players = 1; Type = 'EM'; Theme = 'Cards' }
    "Popeye Saves the Earth (Bally 1994)"                                                        = @{ IPDBNum = 1851; Players = 4; Type = 'SS'; Theme = 'Cartoon, Licensed Theme' }
    "Poseidon (Gottlieb 1978)"                                                                   = @{ IPDBNum = 1852; Players = 1; Type = 'EM'; Theme = 'Mythology, Aquatic' }
    "Positronic (Original 2016)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Post Time (Williams 1969)"                                                                  = @{ IPDBNum = 1853; Players = 1; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Predator (Original 2019)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Predator (Original 2023)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Predator 2 (Original 2019)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Price is Right - 2 For the Price of 1, The (Original 2023)"                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Game Show' }
    "Price is Right - 50 Year, The (Original 2022)"                                              = @{ IPDBNum = 0; Players = -14; Type = 'SS'; Theme = 'Game Show' }
    "Price is Right - Five Price Tags, The (Original 2023)"                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Game Show' }
    "Price is Right - Grand Game 2.0, The (Original 2023)"                                       = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Game Show' }
    "Price Is Right - Original, The (Original 2025)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'TV Show, Game Show' }
    "Price is Right - Plinko, The (Original 2022)"                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Game Show' }
    "Primordial Quarry (Original 2024)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Science Fiction' }
    "Primus (Stern 2018)"                                                                        = @{ IPDBNum = 6610; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music, Singing' }
    "Princess Bride, The (Original 2020)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Adventure' }
    "Prison Break (Original 2018)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Pro Pinball The Web (Cunning Developments 1995)"                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction' }
    "Pro Pool (Gottlieb 1973)"                                                                   = @{ IPDBNum = 1866; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Pro-Football (Gottlieb 1973)"                                                               = @{ IPDBNum = 1865; Players = 1; Type = 'EM'; Theme = 'Sports, American Football' }
    "Prodigy, The (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Electronic Music, Rock' }
    "Professional Pinball - Challenger I (Professional Pinball 1981)"                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Pinball' }
    "Professional Pinball - Challenger V (Professional Pinball 1981)"                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Pinball' }
    "Prospector (Sonic 1977)"                                                                    = @{ IPDBNum = 1871; Players = 4; Type = 'EM'; Theme = 'Comedy, American West, Prospecting' }
    "Pseudo Echo (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Psychedelic (Gottlieb 1970)"                                                                = @{ IPDBNum = 1873; Players = 1; Type = 'EM'; Theme = 'Music, Singing, Dancing, Psychedelic' }
    "PT01 (Original 2023)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Testing' }
    "Pulp Fiction (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Crime' }
    "Pulp Fiction (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Punch-Out (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Boxing' }
    "Punchy the Clown (Alvin G. 1993)"                                                           = @{ IPDBNum = 3508; Players = 1; Type = 'SS'; Theme = 'Circus' }
    "Punchy The Cow (Original 2025)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Cartoon, Kids, Boxing, Cow' }
    "Punk Park (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Skateboarding, Sports' }
    "Punk! (Gottlieb 1982)"                                                                      = @{ IPDBNum = 1877; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Purge, The (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Adult' }
    "Puscifer Pinball (Original 2022)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Putin Vodka Mania (Original 2022)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Historical, Drinking, Parody' }
    "Pyramid (Gottlieb 1978)"                                                                    = @{ IPDBNum = 1881; Players = 2; Type = 'EM'; Theme = 'World Places' }
    "Q-Bert''s Quest (Gottlieb 1983)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Queen - The Game - Hits 1 (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Queen - The Game - Hits 2 (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Queen - The Show Must Go On (Original 2022)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Queen (Original 2021)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Queen of Hearts (Gottlieb 1952)"                                                            = @{ IPDBNum = 1891; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Queens of the Stone Age (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Quick Draw (Gottlieb 1975)"                                                                 = @{ IPDBNum = 1893; Players = 2; Type = 'EM'; Theme = 'American West' }
    "Quick! Silver! - A Rush For Riches (Original 2025)"                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Mining' }
    "Quicksilver (Stern 1980)"                                                                   = @{ IPDBNum = 1895; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Quijote (Juegos Populares 1987)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fictional Characters' }
    "R.E.M (Original 2025)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "R2D2 (Original 2019)"                                                                       = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "Rack ''Em Up! (Gottlieb 1983)"                                                              = @{ IPDBNum = 1902; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Rack-A-Ball (Gottlieb 1962)"                                                                = @{ IPDBNum = 1903; Players = 1; Type = 'EM'; Theme = 'Sports, Billiards' }
    "Radical! (Bally 1990)"                                                                      = @{ IPDBNum = 1904; Players = 4; Type = 'SS'; Theme = 'Sports, Skateboarding' }
    "Radical! (prototype) (Bally 1990)"                                                          = @{ IPDBNum = 1904; Players = 4; Type = 'SS'; Theme = 'Skateboarding, Sports' }
    "Radiohead (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Rage Against the Machine (Original 2025)"                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Raid, The (Playmatic 1984)"                                                                 = @{ IPDBNum = 3511; Players = 4; Type = 'SS'; Theme = 'Aviation, Combat, Science Fiction, Aliens' }
    "Rails (Original 2025)"                                                                      = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Trains' }
    "Rainbow (Gottlieb 1956)"                                                                    = @{ IPDBNum = 1911; Players = 1; Type = 'EM'; Theme = 'American West' }
    "Rainbow (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Raiponce (Original 2021)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Movie' }
    "Rally (Taito do Brasil 1980)"                                                               = @{ IPDBNum = 4581; Players = 4; Type = 'SS'; Theme = 'Auto Racing, Car Rally' }
    "Rambo (Original 2019)"                                                                      = @{ IPDBNum = 1922; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Rambo First Blood Part II (Original 2020)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Rammstein - Fire & Power (Original 2023)"                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Ramones (Original 2021)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Rancho (Gottlieb 1966)"                                                                     = @{ IPDBNum = 1917; Players = 1; Type = 'EM'; Theme = 'American West' }
    "Rancho (Williams 1976)"                                                                     = @{ IPDBNum = 1918; Players = 2; Type = 'EM'; Theme = 'American West' }
    "Rapid Fire (Bally 1982)"                                                                    = @{ IPDBNum = 3568; Players = 4; Type = 'SS'; Theme = 'Outer Space, Aliens, Combat' }
    "Rat Fink (Original 2016)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon' }
    "Rat Fink (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = ''; Theme = 'Hot Rod Culture' }
    "Rattlecan (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Graffiti' }
    "Raven (Gottlieb 1986)"                                                                      = @{ IPDBNum = 1922; Players = 4; Type = 'SS'; Theme = 'Combat' }
    "Rawhide (Stern 1977)"                                                                       = @{ IPDBNum = 3545; Players = 0; Type = 'EM'; Theme = 'American West' }
    "Raygun Runner (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cyberpunk' }
    "Re-Animator - Trilogy Edition (Original 2022)"                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Re-Animator (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Ready Player One (Original 2024)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Ready...Aim...Fire! (Gottlieb 1983)"                                                        = @{ IPDBNum = 1924; Players = 4; Type = 'SS'; Theme = 'Shooting Gallery' }
    "Red & Ted''s Road Show (Williams 1994)"                                                     = @{ IPDBNum = 1972; Players = 4; Type = 'SS'; Theme = 'Travel' }
    "Red Baron (Chicago Coin 1975)"                                                              = @{ IPDBNum = 1933; Players = 2; Type = 'EM'; Theme = 'Adventure, Combat' }
    "Red Electric Rhapsody (Original 2025)"                                                      = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Electric Guitars' }
    "Red Hot Chili Peppers (Original 2021)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Red Hot Pinball (Original 2021)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Red Sonja (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Fantasy' }
    "Ren & Stimpy Space Madness (Original 2024)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Rescue 911 (Gottlieb 1994)"                                                                 = @{ IPDBNum = 1951; Players = 4; Type = 'SS'; Theme = 'Rescue, Fire Fighting, Police' }
    "Resident Alien (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Comedy, TV Show, Comics' }
    "Resident Evil (Original 2022)"                                                              = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Horror, Movie, Video Game' }
    "Resident Evil VII (Original 2019)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Video Game' }
    "Retro King (Original 2004)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = '' }
    "Retro Zombie Adventure Land (Original 2016)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Supernatural' }
    "Return of the Living Dead (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie' }
    "Return of the Living Dead, The (Original 2020)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "Return Of The Living Dead, The (Original 2024)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Zombies, Horror, Movie' }
    "Rey de Diamantes (Petaco 1967)"                                                             = @{ IPDBNum = 4368; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Riccione (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Holiday, Italy' }
    "Rick and Morty (Original 2019)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Animation, TV Show' }
    "Rick and Morty (Original 2023)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation' }
    "Rider''s Surf (Jocmatic 1986)"                                                              = @{ IPDBNum = 4102; Players = 4; Type = 'SS'; Theme = 'Sports, Surfing, Aquatic' }
    "Rio Travel (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Travel' }
    "Ripley''s Believe it or Not! (Stern 2004)"                                                  = @{ IPDBNum = 4917; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Exploration, Adventure' }
    "Rise Against (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Riverboat Gambler (Williams 1990)"                                                          = @{ IPDBNum = 1966; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "Ro Go (Bally 1974)"                                                                         = @{ IPDBNum = 1969; Players = 4; Type = 'EM'; Theme = 'Fantasy, Norse Mythology' }
    "Road Blues (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Road Kings (Williams 1986)"                                                                 = @{ IPDBNum = 1970; Players = 4; Type = 'SS'; Theme = 'Apocalyptic, Motorcycles' }
    "Road Race (Gottlieb 1969)"                                                                  = @{ IPDBNum = 1971; Players = 1; Type = 'EM'; Theme = 'Sports, Auto Racing' }
    "Road Runner (Atari 1979)"                                                                   = @{ IPDBNum = 3517; Players = 2; Type = 'SS'; Theme = 'Licensed Theme, Kids, Cartoon, American West' }
    "Road Train (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Trains' }
    "Rob Zombie''s Spookshow International (Original 2017)"                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Supernatural, Music' }
    "Robo-War (Gottlieb 1988)"                                                                   = @{ IPDBNum = 1975; Players = 4; Type = 'SS'; Theme = 'Outer Space, Robots, Combat' }
    "Robocop (Data East 1989)"                                                                   = @{ IPDBNum = 1976; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Crime, Police' }
    "Robocop 3 (Original 2018)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction' }
    "Robot (Zaccaria 1985)"                                                                      = @{ IPDBNum = 1977; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Robots' }
    "Robotech: The Macross Saga (Original 2025)"                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Anime, Space Fantasy, Aliens' }
    "Robots Invasion (Original 2024)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Robots' }
    "Rock (Gottlieb 1985)"                                                                       = @{ IPDBNum = 1978; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Rock 2500 (Playmatic 1985)"                                                                 = @{ IPDBNum = 3538; Players = 4; Type = 'SS'; Theme = 'Fantasy, Music, Women' }
    "Rock and Roll (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Rock Encore (Gottlieb 1986)"                                                                = @{ IPDBNum = 1979; Players = 4; Type = 'SS'; Theme = 'Music, Singing' }
    "Rock in Rio (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Rock Music (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Rock' }
    "Rock N Roll Diner (Original 2020)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Singing, Food' }
    "Rock Star (Gottlieb 1978)"                                                                  = @{ IPDBNum = 1983; Players = 1; Type = 'EM'; Theme = 'Music, Singing' }
    "Rock Sugar (Original 2021)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Rock, Pop' }
    "Rockabilly (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Rock, Music' }
    "Rocket III (Bally 1967)"                                                                    = @{ IPDBNum = 1989; Players = 1; Type = 'EM'; Theme = 'Outer Space' }
    "RockMakers (Bally 1968)"                                                                    = @{ IPDBNum = 1980; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Rocky (Gottlieb 1982)"                                                                      = @{ IPDBNum = 1993; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing, Licensed Theme, Movie' }
    "Rocky (Original 2020)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing' }
    "Rocky Balboa (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing, Movie' }
    "Rocky Horror Picture Show, The (Original 2022)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Musical' }
    "Rocky TKO (Original 2021)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing, Movie' }
    "Rocky vs. Balutito (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Sports, Boxing, Movie' }
    "Rod Stewart (Original 2023)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Roller Coaster (Gottlieb 1971)"                                                             = @{ IPDBNum = 2002; Players = 2; Type = 'EM'; Theme = 'Amusement Park, Roller Coasters' }
    "Roller Derby (Bally 1960)"                                                                  = @{ IPDBNum = 2003; Players = 1; Type = 'EM'; Theme = 'Sports, Roller Skating' }
    "Roller Disco (Gottlieb 1980)"                                                               = @{ IPDBNum = 2005; Players = 4; Type = 'SS'; Theme = 'Roller Skating, Music, Happiness' }
    "RollerCoaster Tycoon (Stern 2002)"                                                          = @{ IPDBNum = 4536; Players = 4; Type = 'SS'; Theme = 'Roller Coasters, Licensed Theme, Amusement Park' }
    "Rollergames (Williams 1990)"                                                                = @{ IPDBNum = 2006; Players = 4; Type = 'SS'; Theme = 'Sports, Roller Derby, Roller Skating, Licensed Theme' }
    "Rollet (Barok Co 1931)"                                                                     = @{ IPDBNum = 2007; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Rolling Stones - B&W Edition (Bally 1980)"                                                  = @{ IPDBNum = 2010; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Music, Rock n roll' }
    "Rolling Stones (Bally 1980)"                                                                = @{ IPDBNum = 2010; Players = 4; Type = 'SS'; Theme = 'Celebrities, Licensed Theme, Music, Rock n roll' }
    "Rolling Stones, The (Stern 2011)"                                                           = @{ IPDBNum = 5668; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Music' }
    "Roman Victory (Taito do Brasil 1977)"                                                       = @{ IPDBNum = 5493; Players = 4; Type = 'SS'; Theme = 'Roman History' }
    "Route 66 (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Travel, Cars' }
    "Roy Orbison (Original 2020)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Royal Blood (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music, Rock' }
    "Royal Flush (Gottlieb 1976)"                                                                = @{ IPDBNum = 2035; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Royal Flush Deluxe (Gottlieb 1983)"                                                         = @{ IPDBNum = 2036; Players = 4; Type = 'SS'; Theme = 'Cards, Gambling' }
    "Royal Guard (Gottlieb 1968)"                                                                = @{ IPDBNum = 2037; Players = 1; Type = 'EM'; Theme = 'World Places, Historical' }
    "Royal Pair - 2 Pop Bumper Edition (Gottlieb 1974)"                                          = @{ IPDBNum = 2038; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Royal Pair (Gottlieb 1974)"                                                                 = @{ IPDBNum = 2038; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Running Horse (Inder 1976)"                                                                 = @{ IPDBNum = 4414; Players = 1; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Rush 2112 (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Rush LE Tribute (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Safe Australia (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "Safe Cracker (Bally 1996)"                                                                  = @{ IPDBNum = 3782; Players = 4; Type = 'SS'; Theme = 'Crime, Money, Police' }
    "Saint Seiya - I Cavalieri dello zodiaco - Cabinet Edition (Original 2022)"                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Saint Seiya - I Cavalieri dello zodiaco - Desktop Edition (Original 2022)"                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Anime' }
    "Saloon (Taito do Brasil 1978)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'American West' }
    "Salsa (Original 2021)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music' }
    "Samba (LTD do Brasil 1976)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Dancing' }
    "San Francisco (Williams 1964)"                                                              = @{ IPDBNum = 2049; Players = 2; Type = 'EM'; Theme = 'American Places' }
    "San Ku Kai (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Anime, TV Show' }
    "Sandra - The 80''s Pop Star (Original 2025)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Pop' }
    "Sands of the Aton (Original 2023)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Mythology' }
    "Santana (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Satin Doll (Williams 1975)"                                                                 = @{ IPDBNum = 2057; Players = 2; Type = 'EM'; Theme = 'Music, Singing' }
    "Saturday Night Fever (Original 2025)"                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Musical, Movie' }
    "Saucerer (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy, Wizards' }
    "Saving Wallden (Original 2024)"                                                             = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Adventure' }
    "Saw (Original 2022)"                                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Horror, Movie' }
    "Saxon (Original 2025)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Scared Stiff (Bally 1996)"                                                                  = @{ IPDBNum = 3915; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Horror, Supernatural' }
    "Scarface - Balls and Power (Original 2020)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Schuss (Rally 1968)"                                                                        = @{ IPDBNum = 3541; Players = 0; Type = 'EM'; Theme = 'Sports, Skiing' }
    "Scooby-Doo! (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation, Kids' }
    "Scooby-Doo! and KISS - Rock ''n Roll Mystery (Original 2015)"                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Music, Rock, Kids' }
    "Scorpion (Williams 1980)"                                                                   = @{ IPDBNum = 2067; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Scorpions (Original 2024)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Scott Pilgrim vs. the World (Original 2021)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Movie' }
    "Scram! (Hutchison 1932)"                                                                    = @{ IPDBNum = 5138; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Scramble (Tecnoplay 1987)"                                                                  = @{ IPDBNum = 3557; Players = 4; Type = 'SS'; Theme = 'Sports, Motorcycles, Motocross' }
    "Scream (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie' }
    "Scrooged (Original 2019)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas' }
    "Scuba (Gottlieb 1970)"                                                                      = @{ IPDBNum = 2077; Players = 2; Type = 'EM'; Theme = 'Mermaids, Mythology, Scuba Diving, Swimming, Aquatic' }
    "Sea Jockeys (Williams 1951)"                                                                = @{ IPDBNum = 2084; Players = 1; Type = 'EM'; Theme = 'Sports, Aquatic' }
    "Sea Ray (Bally 1971)"                                                                       = @{ IPDBNum = 2085; Players = 2; Type = 'EM'; Theme = 'Sports, Aquatic, Fishing, Scuba Diving' }
    "Seawitch (Stern 1980)"                                                                      = @{ IPDBNum = 2089; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Secret Agent (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Cartoon' }
    "Secret Service (Data East 1988)"                                                            = @{ IPDBNum = 2090; Players = 4; Type = 'SS'; Theme = 'Police, Espionage' }
    "Seinfeld (Original 2021)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Senna - Prototype Edition (Culik Pinball 2020)"                                             = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Auto Racing' }
    "Sepultura (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Serious Sam II (Original 2019)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Serious Sam Pinball (Original 2017)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Sesame Street (Original 2021)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Kids' }
    "Seven Winner (Inder 1973)"                                                                  = @{ IPDBNum = 4407; Players = 1; Type = 'EM'; Theme = 'Gambling, Playing Dice, Games' }
    "Sexy Girl - Nude Edition (Arkon 1980)"                                                      = @{ IPDBNum = 2106; Players = 4; Type = 'SS'; Theme = 'Women, Adult' }
    "Sexy Girl (Arkon 1980)"                                                                     = @{ IPDBNum = 2106; Players = 4; Type = 'SS'; Theme = 'Women, Adult' }
    "Shadow, The (Bally 1994)"                                                                   = @{ IPDBNum = 2528; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Detective, Supernatural, Comics, Movie' }
    "Shamrock (Inder 1977)"                                                                      = @{ IPDBNum = 5717; Players = 0; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Shangri-La (Williams 1967)"                                                                 = @{ IPDBNum = 2110; Players = 4; Type = 'EM'; Theme = 'World Places' }
    "Shaq Attaq (Gottlieb 1995)"                                                                 = @{ IPDBNum = 2874; Players = 4; Type = 'SS'; Theme = 'Sports, Basketball, Celebrities, Licensed Theme' }
    "Shark (Taito do Brasil 1982)"                                                               = @{ IPDBNum = 4582; Players = 4; Type = 'SS'; Theme = 'Boats, Scuba Diving, Nautical, Aquatic' }
    "Sharkey''s Shootout (Stern 2000)"                                                           = @{ IPDBNum = 4492; Players = 4; Type = 'SS'; Theme = 'Sports, Billiards' }
    "Sharp Shooter II (Game Plan 1983)"                                                          = @{ IPDBNum = 2114; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Sharpshooter (Bally 1961)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Arcade, Shooting Gallery, Flipperless' }
    "Sharpshooter (Game Plan 1979)"                                                              = @{ IPDBNum = 2113; Players = 4; Type = 'SS'; Theme = 'American West' }
    "Sheriff (Gottlieb 1971)"                                                                    = @{ IPDBNum = 2116; Players = 4; Type = 'EM'; Theme = 'American West, Law Enforcement' }
    "Sherokee (Rowamet 1978)"                                                                    = @{ IPDBNum = 6707; Players = 0; Type = 'EM'; Theme = 'American West, Historical, Native Americans' }
    "Shining, The (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Shining, The (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror' }
    "Ship Ahoy (Gottlieb 1976)"                                                                  = @{ IPDBNum = 2119; Players = 1; Type = 'EM'; Theme = 'Adventure, Pirates, Nautical' }
    "Ship-Mates (Gottlieb 1964)"                                                                 = @{ IPDBNum = 2120; Players = 4; Type = 'EM'; Theme = 'Nautical' }
    "Shock (Taito do Brasil 1979)"                                                               = @{ IPDBNum = 4573; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Shooting Star (Junior) (Daval 1934)"                                                        = @{ IPDBNum = 6021; Players = 1; Type = 'EM'; Theme = 'Flipperless' }
    "Shooting the Rapids (Zaccaria 1979)"                                                        = @{ IPDBNum = 3606; Players = 4; Type = 'SS'; Theme = 'Canoeing, Native Americans, Water Sports' }
    "Short Circuit (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Science Fiction, Movie, Robots' }
    "Shovel Knight (Original 2017)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Shrek (Stern 2008)"                                                                         = @{ IPDBNum = 5301; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Fictional, Animation, Movie, Kids' }
    "Shrek the Halls (Original 2019)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Animation, Kids, Movie' }
    "Shuffle Inn (Williams 1989)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling, Flipperless' }
    "Silent Night Deadly Night (Original 2016)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Horror' }
    "Silver Bullet (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Horror, Anime' }
    "Silver Cup (Genco 1933)"                                                                    = @{ IPDBNum = 2146; Players = 1; Type = 'PM'; Theme = '' }
    "Silver Line (Bill Port 1970)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Flipperless' }
    "Silver Slugger (Gottlieb 1990)"                                                             = @{ IPDBNum = 2152; Players = 4; Type = 'SS'; Theme = 'Sports, Baseball' }
    "Silverball Mania (Bally 1980)"                                                              = @{ IPDBNum = 2156; Players = 4; Type = 'SS'; Theme = 'Sports, Pinball, Fantasy' }
    "Simple Minds (Original 2024)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Simpsons Christmas, The (Original 2019)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, TV Show, Animation' }
    "Simpsons Kooky Carnival, The (Stern 2006)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Animation, Carnival' }
    "Simpsons Pinball Party, The (Stern 2003)"                                                   = @{ IPDBNum = 4674; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Animation, Cartoon, Comedy' }
    "Simpsons Treehouse of Horror, The - Starlion Edition (Original 2020)"                       = @{ IPDBNum = 4674; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Simpsons Treehouse of Horror, The (Original 2020)"                                          = @{ IPDBNum = 4674; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Simpsons, The (Data East 1990)"                                                             = @{ IPDBNum = 2158; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Animation, Cartoon, Comedy' }
    "Sin City - PuP-Pack Edition (Original 2022)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Noir, Comics, Movie' }
    "Sin City (Original 2022)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Noir, Comics, Movie' }
    "Sinbad (Gottlieb 1978)"                                                                     = @{ IPDBNum = 2159; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "Sing Along (Gottlieb 1967)"                                                                 = @{ IPDBNum = 2160; Players = 1; Type = 'EM'; Theme = 'Music, Singing' }
    "Sir Lancelot (Peyper 1994)"                                                                 = @{ IPDBNum = 4949; Players = 0; Type = 'SS'; Theme = 'Medieval, Fantasy' }
    "Sittin'' Pretty (Gottlieb 1958)"                                                            = @{ IPDBNum = 2164; Players = 1; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Six Million Dollar Man, The (Bally 1978)"                                                   = @{ IPDBNum = 2165; Players = 6; Type = 'SS'; Theme = 'TV Show, Fictional, Licensed Theme' }
    "Skate and Destroy (Original 2019)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Skateboarding' }
    "Skateball (Bally 1980)"                                                                     = @{ IPDBNum = 2170; Players = 4; Type = 'SS'; Theme = 'Sports, Skateboarding' }
    "Skateboard (Inder 1980)"                                                                    = @{ IPDBNum = 4479; Players = 4; Type = 'SS'; Theme = 'Sports, Skateboarding' }
    "Skipper (Gottlieb 1969)"                                                                    = @{ IPDBNum = 2189; Players = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Nautical' }
    "Skittles (Original 2019)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = '' }
    "Sky Jump (Gottlieb 1974)"                                                                   = @{ IPDBNum = 2195; Players = 1; Type = 'EM'; Theme = 'Parachuting, Sports, Skydiving' }
    "Sky Kings (Bally 1974)"                                                                     = @{ IPDBNum = 2196; Players = 1; Type = 'EM'; Theme = 'Parachuting, Skydiving, Sports' }
    "Sky Ride (Genco 1933)"                                                                      = @{ IPDBNum = 2200; Players = 1; Type = 'PM'; Theme = 'Flipperless' }
    "Sky-Line (Gottlieb 1965)"                                                                   = @{ IPDBNum = 3240; Players = 1; Type = 'EM'; Theme = 'Nightclubs, Nightlife' }
    "Skylab (Williams 1974)"                                                                     = @{ IPDBNum = 2202; Players = 1; Type = 'EM'; Theme = 'Space Exploration' }
    "Skyrocket (Bally 1971)"                                                                     = @{ IPDBNum = 2204; Players = 2; Type = 'EM'; Theme = 'Happiness, Circus, Carnival' }
    "Skyscraper (Bally 1934)"                                                                    = @{ IPDBNum = 2205; Players = 1; Type = 'EM'; Theme = 'City Skyline' }
    "Skyway (Williams 1954)"                                                                     = @{ IPDBNum = 2206; Players = 1; Type = 'EM'; Theme = 'Space Age, Travel, Aquatic, Women' }
    "Slash (Original 2025)"                                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Slash''s Snakepit It''s Five O''clock Somewhere (Original 2025)"                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Slayer (Original 2022)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Sleic Pin-BALL - Cabinet Edition (Sleic 1994)"                                              = @{ IPDBNum = 4620; Players = 4; Type = 'SS'; Theme = '' }
    "Sleic Pin-BALL - Desktop Edition (Sleic 1994)"                                              = @{ IPDBNum = 4620; Players = 4; Type = 'SS'; Theme = '' }
    "Sleic Pin-BALL (Sleic 1994)"                                                                = @{ IPDBNum = 4620; Players = 4; Type = 'SS'; Theme = '' }
    "Slick Chick (Gottlieb 1963)"                                                                = @{ IPDBNum = 2208; Players = 1; Type = 'EM'; Theme = 'Women' }
    "Slipknot (Original 2021)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Smart Set (Williams 1969)"                                                                  = @{ IPDBNum = 2215; Players = 4; Type = 'EM'; Theme = 'Boats, Recreation, Affluence, Aquatic' }
    "Smokey and the Bandit (Original 2021)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Smooth Hot Ride 3 - From Natchez to Mike Vegas (Original 2023)"                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Nevada, Las Vegas, Travel' }
    "Snake DMD (Original 2021)"                                                                  = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "Snake Machine (Taito do Brasil 1982)"                                                       = @{ IPDBNum = 4585; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Snooker (Gottlieb 1985)"                                                                    = @{ IPDBNum = 5343; Players = 4; Type = 'SS'; Theme = '' }
    "Snow Derby (Gottlieb 1970)"                                                                 = @{ IPDBNum = 2229; Players = 2; Type = 'EM'; Theme = 'Sports, Skiing, Snowmobiling' }
    "Snow Queen (Gottlieb 1970)"                                                                 = @{ IPDBNum = 2230; Players = 4; Type = 'EM'; Theme = 'Sports, Skiing' }
    "Snowman, The (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Movie' }
    "Soccer (Gottlieb 1975)"                                                                     = @{ IPDBNum = 2233; Players = 2; Type = 'EM'; Theme = 'Sports, Soccer' }
    "Soccer (Williams 1964)"                                                                     = @{ IPDBNum = 2232; Players = 1; Type = 'EM'; Theme = 'Sports, Soccer' }
    "Soccer Kings (Zaccaria 1982)"                                                               = @{ IPDBNum = 2235; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Solar City (Gottlieb 1977)"                                                                 = @{ IPDBNum = 2237; Players = 2; Type = 'EM'; Theme = 'Fantasy' }
    "Solar Fire (Williams 1981)"                                                                 = @{ IPDBNum = 2238; Players = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Solar Ride (Electromatic 1982)"                                                             = @{ IPDBNum = 5696; Players = 4; Type = 'EM'; Theme = 'Outer Space, Space Fantasy' }
    "Solar Ride (Gottlieb 1979)"                                                                 = @{ IPDBNum = 2239; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Solar Ride (Rowamet 1982)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Outer Space, Space Fantasy' }
    "Solar Sailor (Original 2016)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Solar Wars (Sonic 1986)"                                                                    = @{ IPDBNum = 3273; Players = 0; Type = 'SS'; Theme = '' }
    "Solids N Stripes (Williams 1971)"                                                           = @{ IPDBNum = 2240; Players = 2; Type = 'EM'; Theme = 'Billiards' }
    "Solitaire (Gottlieb 1967)"                                                                  = @{ IPDBNum = 2241; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Sonic The Hedgehog (Original 2005)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Sonic the Hedgehog 2 (Original 2019)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Sonic the Hedgehog Spinball (Original 2020)"                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Sons of Anarchy (Original 2019)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Sopranos, The (Stern 2005)"                                                                 = @{ IPDBNum = 5053; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Mobsters, Crime, TV Show' }
    "Sorcerer (Williams 1985)"                                                                   = @{ IPDBNum = 2242; Players = 4; Type = 'SS'; Theme = 'Fantasy, Wizards, Magic, Dragons' }
    "Soul Reaver (Original 2019)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game' }
    "Sound Stage (Chicago Coin 1976)"                                                            = @{ IPDBNum = 2243; Players = 2; Type = 'EM'; Theme = 'Music, Singing' }
    "South Park (Sega 1999)"                                                                     = @{ IPDBNum = 4444; Players = 6; Type = 'SS'; Theme = 'Licensed Theme, Animation, Comedy, Movie, TV Show' }
    "South Park Pinball (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation' }
    "South Park Xmas Pinball (Original 2020)"                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas' }
    "Soylent Green (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Police, Crime' }
    "Space 1999 (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outer Space, TV Show, Science Fiction' }
    "Space Cadet (Microsoft 1995)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Video Game' }
    "Space Gambler (Playmatic 1978)"                                                             = @{ IPDBNum = 2250; Players = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction' }
    "Space Invaders (Bally 1980)"                                                                = @{ IPDBNum = 2252; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Space Jam (Sega 1996)"                                                                      = @{ IPDBNum = 0; Players = 6; Type = 'SS'; Theme = 'Sports, Basketball, Celebrities, Licensed Theme, Kids, Movie, Animation, Cartoon' }
    "Space Mission (Williams 1976)"                                                              = @{ IPDBNum = 2253; Players = 4; Type = 'EM'; Theme = 'Outer Space' }
    "Space Oddity (Original 2022)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Science Fiction' }
    "Space Odyssey (Williams 1976)"                                                              = @{ IPDBNum = 2254; Players = 2; Type = 'EM'; Theme = 'Outer Space' }
    "Space Orbit (Gottlieb 1972)"                                                                = @{ IPDBNum = 2255; Players = 1; Type = 'EM'; Theme = 'Outer Space' }
    "Space Patrol (Taito do Brasil 1978)"                                                        = @{ IPDBNum = 6582; Players = 0; Type = 'EM'; Theme = 'Outer Space' }
    "Space Platform - Murray Leinster (Original 2024)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction' }
    "Space Poker (LTD do Brasil 1982)"                                                           = @{ IPDBNum = 5886; Players = 2; Type = 'SS'; Theme = 'Science Fiction, Outer Space, Cards, Gambling' }
    "Space Rider (Geiger 1980)"                                                                  = @{ IPDBNum = 4018; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Space Riders (Atari 1978)"                                                                  = @{ IPDBNum = 2258; Players = 4; Type = 'SS'; Theme = 'Motorcycles, Travel, Futuristic Racing, Science Fiction' }
    "Space Romance (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Outer Space' }
    "Space Sheriff Gavan (X-Or) (Original 2021)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Police' }
    "Space Shuttle (Taito do Brasil 1985)"                                                       = @{ IPDBNum = 4583; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Space Shuttle (Williams 1984)"                                                              = @{ IPDBNum = 2260; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Space Station (Williams 1987)"                                                              = @{ IPDBNum = 2261; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Space Time (Bally 1972)"                                                                    = @{ IPDBNum = 2262; Players = 4; Type = 'EM'; Theme = 'Outer Space' }
    "Space Train (MAC 1987)"                                                                     = @{ IPDBNum = 3895; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Space Tug - Murray Leinster (Original 2024)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Science Fiction' }
    "Space Walk (Gottlieb 1979)"                                                                 = @{ IPDBNum = 2263; Players = 2; Type = 'EM'; Theme = 'Outer Space' }
    "SpaceRamp (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Outer Space' }
    "Spanish Eyes (Williams 1972)"                                                               = @{ IPDBNum = 2265; Players = 1; Type = 'EM'; Theme = 'Dancing, Music, Women, World Places' }
    "Spark Plugs (Williams 1951)"                                                                = @{ IPDBNum = 2267; Players = 1; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Spawn (Original 2023)"                                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics' }
    "Speakeasy (Bally 1982)"                                                                     = @{ IPDBNum = 2270; Players = 2; Type = 'SS'; Theme = 'American History' }
    "Speakeasy (Playmatic 1977)"                                                                 = @{ IPDBNum = 2269; Players = 4; Type = 'EM'; Theme = 'American History, Cards, Gambling' }
    "Speakeasy 4 (Bally 1982)"                                                                   = @{ IPDBNum = 4342; Players = 4; Type = 'SS'; Theme = 'American History' }
    "Special Force (Bally 1986)"                                                                 = @{ IPDBNum = 2272; Players = 0; Type = 'SS'; Theme = 'Combat' }
    "Species (Original 2023)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Spectrum (Bally 1982)"                                                                      = @{ IPDBNum = 2274; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Speed Racer (Original 2018)"                                                                = @{ IPDBNum = 0; Players = 2; Type = 'EM'; Theme = 'Anime, Kids' }
    "Speed Test (Taito do Brasil 1982)"                                                          = @{ IPDBNum = 4589; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Spellcast Machine, The (Original 2024)"                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Psychedelic' }
    "Spider-Man - Classic Edition (Stern 2007)"                                                  = @{ IPDBNum = 5237; Players = 4; Type = 'SS'; Theme = 'Licensed, Comics, Superheroes' }
    "Spider-Man (Black Suited) (Stern 2007)"                                                     = @{ IPDBNum = 5650; Players = 4; Type = 'SS'; Theme = 'Superheroes' }
    "Spider-Man (Stern 2007)"                                                                    = @{ IPDBNum = 5237; Players = 4; Type = 'SS'; Theme = 'Licensed, Comics, Superheroes' }
    "Spider-Man (Vault Edition) - Classic Edition (Stern 2016)"                                  = @{ IPDBNum = 6328; Players = 0; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes' }
    "Spider-Man (Vault Edition) (Stern 2016)"                                                    = @{ IPDBNum = 6328; Players = 0; Type = 'SS'; Theme = 'Licensed Theme, Comics, Superheroes' }
    "Spin Out (Gottlieb 1975)"                                                                   = @{ IPDBNum = 2286; Players = 1; Type = 'EM'; Theme = 'Sports, Auto Racing' }
    "Spin Wheel (Gottlieb 1968)"                                                                 = @{ IPDBNum = 2287; Players = 4; Type = 'EM'; Theme = 'Happiness, Games' }
    "Spin-A-Card (Gottlieb 1969)"                                                                = @{ IPDBNum = 2288; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Spinning Wheel (Automaticos 1970)"                                                          = @{ IPDBNum = 6402; Players = 1; Type = 'EM'; Theme = 'Gambling' }
    "Spirit (Gottlieb 1982)"                                                                     = @{ IPDBNum = 2292; Players = 4; Type = 'SS'; Theme = 'Supernatural' }
    "Spirit of 76 (Gottlieb 1975)"                                                               = @{ IPDBNum = 2293; Players = 4; Type = 'EM'; Theme = 'Historical' }
    "Splatter Blast Studio (Original 2024)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Painting' }
    "Splatterhouse (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Horror' }
    "Split Second (Stern 1981)"                                                                  = @{ IPDBNum = 2297; Players = 4; Type = 'SS'; Theme = 'Carnival, Circus, Happiness' }
    "SpongeBob (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Animation, Kids' }
    "SpongeBob Squarepants Pinball Adventure - Bronze Edition (Original 2023)"                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'TV Show, Animation, Kids' }
    "SpongeBob Squarepants Pinball Adventure - Gold Edition (Original 2023)"                     = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'TV Show, Animation, Kids' }
    "SpongeBob Squarepants Pinball Adventure - Platinum Edition (Original 2023)"                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'TV Show, Animation, Kids' }
    "SpongeBob''s Bikini Bottom Pinball (Original 2021)"                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Animation, Kids' }
    "Spooky Wednesday (Original 2024)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Supernatural, TV Show, Fantasy' }
    "Spot a Card (Gottlieb 1960)"                                                                = @{ IPDBNum = 2318; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Spot Pool (Gottlieb 1976)"                                                                  = @{ IPDBNum = 2316; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Spring Break (Gottlieb 1987)"                                                               = @{ IPDBNum = 2324; Players = 4; Type = 'SS'; Theme = 'Aquatic, Happiness' }
    "Spy Hunter (Bally 1984)"                                                                    = @{ IPDBNum = 2328; Players = 4; Type = 'SS'; Theme = 'Video Game, Espionage' }
    "Squid Game (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Survival' }
    "Stampede (Stern 1977)"                                                                      = @{ IPDBNum = 5232; Players = 2; Type = 'EM'; Theme = 'American West' }
    "Star Action (Williams 1973)"                                                                = @{ IPDBNum = 2342; Players = 1; Type = 'EM'; Theme = 'Show Business' }
    "Star Fire (Playmatic 1985)"                                                                 = @{ IPDBNum = 3453; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Star Gazer (Stern 1980)"                                                                    = @{ IPDBNum = 2346; Players = 4; Type = 'SS'; Theme = 'Astrology' }
    "Star God (Zaccaria 1980)"                                                                   = @{ IPDBNum = 3458; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Star Knights (Original 2025)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Anime, Space Fantasy' }
    "Star Light (Williams 1984)"                                                                 = @{ IPDBNum = 2362; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy, Wizards' }
    "Star Mission (Durham 1977)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Science Fiction, Outer Space' }
    "Star Pool (Williams 1974)"                                                                  = @{ IPDBNum = 2352; Players = 4; Type = 'EM'; Theme = 'Sports, Billiards' }
    "Star Race (Gottlieb 1980)"                                                                  = @{ IPDBNum = 2353; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Outer Space' }
    "Star Ship (Bally 1976)"                                                                     = @{ IPDBNum = 3498; Players = 2; Type = 'EM'; Theme = 'Space Exploration, Outer Space, Science Fiction' }
    "Star Tours (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Star Trek - Mirror Universe Edition (Bally 1979)"                                           = @{ IPDBNum = 2355; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie' }
    "Star Trek - Spock Tribute (Original 2022)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Tribute, TV Show, Movie' }
    "Star Trek - The Mirror Universe (Original 2014)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy' }
    "Star Trek - The Next Generation (Williams 1993)"                                            = @{ IPDBNum = 2357; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, TV Show, Space Exploration, Science Fiction' }
    "Star Trek - Voyager - Seven of Nine (Borg Edition) (Original 2022)"                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Outer Space, Science Fiction, Space Fantasy, TV Show' }
    "Star Trek (Bally 1979)"                                                                     = @{ IPDBNum = 2355; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie' }
    "Star Trek (Data East 1991)"                                                                 = @{ IPDBNum = 2356; Players = 0; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie' }
    "Star Trek (Enterprise Limited Edition) (Stern 2013)"                                        = @{ IPDBNum = 6046; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Outer Space, Science Fiction, Space Fantasy, Movie' }
    "Star Trek (Gottlieb 1971)"                                                                  = @{ IPDBNum = 2354; Players = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Star Trip (Game Plan 1979)"                                                                 = @{ IPDBNum = 3605; Players = 0; Type = 'SS'; Theme = 'Outer Space' }
    "Star Wars - Bounty Hunter (Original 2021)"                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy, Movie' }
    "Star Wars - Episode I (Original 2023)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy, Movie' }
    "Star Wars - The Bad Batch (Original 2022)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Star Wars - The Empire Strikes Back (Hankin 1980)"                                          = @{ IPDBNum = 2868; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie' }
    "Star Wars (Data East 1992)"                                                                 = @{ IPDBNum = 2358; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie' }
    "Star Wars (Original 2016)"                                                                  = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy, Movie' }
    "Star Wars (Original 2019)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy, Movie' }
    "Star Wars (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction' }
    "Star Wars (Sonic 1987)"                                                                     = @{ IPDBNum = 4513; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie' }
    "Star Wars Redux (Original 2021)"                                                            = @{ IPDBNum = 0; Players = 2; Type = 'SS'; Theme = 'Science Fiction, Space Fantasy, Movie' }
    "Star Wars Trilogy Special Edition (Sega 1997)"                                              = @{ IPDBNum = 4054; Players = 6; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Space Fantasy, Movie' }
    "Star-Jet (Bally 1963)"                                                                      = @{ IPDBNum = 2347; Players = 2; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Stardust (Williams 1971)"                                                                   = @{ IPDBNum = 2359; Players = 4; Type = 'EM'; Theme = 'Happiness, Dancing' }
    "Stargate (Gottlieb 1995)"                                                                   = @{ IPDBNum = 2847; Players = 4; Type = 'SS'; Theme = 'Outer Space, Mythology, TV Show' }
    "Stars (Stern 1978)"                                                                         = @{ IPDBNum = 2366; Players = 4; Type = 'SS'; Theme = 'Outer Space, Exploration' }
    "Starship Troopers - VPN Edition (Sega 1997)"                                                = @{ IPDBNum = 4341; Players = 6; Type = 'SS'; Theme = 'Combat, Aliens, Science Fiction, Movie, Licensed Theme' }
    "Starship Troopers (Sega 1997)"                                                              = @{ IPDBNum = 4341; Players = 6; Type = 'SS'; Theme = 'Combat, Aliens, Science Fiction, Movie, Licensed Theme' }
    "Steel Panther 1987 (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Stellar Airship (Geiger 1979)"                                                              = @{ IPDBNum = 4016; Players = 4; Type = 'SS'; Theme = 'Fantasy, Outer Space' }
    "Stellar Wars (Williams 1979)"                                                               = @{ IPDBNum = 2372; Players = 0; Type = 'SS'; Theme = 'Fantasy, Outer Space, Science Fiction' }
    "Stephen King''s Children of the Corn (Original 2019)"                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror' }
    "Stephen King''s Pet Sematary (Original 2019)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror' }
    "Stephen King''s Sleepwalkers (Original 2019)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror' }
    "Stephen King''s The Running Man (Original 2019)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Steve Miller Band (Original 2025)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Stick Figure (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Still Crazy (Williams 1984)"                                                                = @{ IPDBNum = 3730; Players = 1; Type = 'SS'; Theme = 'American History, Hillbillies, Rural Living' }
    "Stingray (Stern 1977)"                                                                      = @{ IPDBNum = 2377; Players = 4; Type = 'SS'; Theme = 'Scuba Diving, Sports, Aquatic' }
    "Stock Car (Gottlieb 1970)"                                                                  = @{ IPDBNum = 2378; Players = 1; Type = 'EM'; Theme = 'Auto Racing' }
    "Straight Flush (Williams 1970)"                                                             = @{ IPDBNum = 2393; Players = 1; Type = 'EM'; Theme = 'Gambling, Cards, Poker' }
    "Strange Science (Bally 1986)"                                                               = @{ IPDBNum = 2396; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Strange World (Gottlieb 1978)"                                                              = @{ IPDBNum = 2397; Players = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Stranger Things - Stranger Edition - Season 4 Edition (Original 2018)"                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Science Fiction, Fantasy, Horror' }
    "Stranger Things - Stranger Edition - Season 4 Premium Edition (Original 2018)"              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Science Fiction, Fantasy, Horror' }
    "Stranger Things - Stranger Edition (Original 2018)"                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Science Fiction, Fantasy, Horror' }
    "Stranger Things (Original 2017)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Science Fiction, Fantasy, Horror' }
    "Strato-Flite (Williams 1974)"                                                               = @{ IPDBNum = 2398; Players = 4; Type = 'EM'; Theme = 'Aviation, Outer Space' }
    "Stray Cats - Pup-Pack Edition (Original 2025)"                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Stray Cats (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Street Fighter II (Gottlieb 1993)"                                                          = @{ IPDBNum = 2403; Players = 4; Type = 'SS'; Theme = 'Martial Arts, Video Game' }
    "Streets of Rage (Original 2018)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Strike (Zaccaria 1978)"                                                                     = @{ IPDBNum = 3363; Players = 1; Type = 'SS'; Theme = 'Bowling' }
    "Strike Master (Williams 1991)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling, Flipperless' }
    "Strike Zone (Williams 1984)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling, Flipperless' }
    "Striker (Gottlieb 1982)"                                                                    = @{ IPDBNum = 2405; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Striker Xtreme (Stern 2000)"                                                                = @{ IPDBNum = 4459; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "Strikes and Spares (Bally 1978)"                                                            = @{ IPDBNum = 2406; Players = 4; Type = 'SS'; Theme = 'Sports, Bowling' }
    "Strikes N'' Spares (Gottlieb 1995)"                                                         = @{ IPDBNum = 4336; Players = 4; Type = 'SS'; Theme = 'Bowling' }
    "Strip Joker Poker (Gottlieb 1978)"                                                          = @{ IPDBNum = 1306; Players = 4; Type = 'EM'; Theme = 'Cards, Gambling, Adult, Poker' }
    "Stripping Funny (Inder 1974)"                                                               = @{ IPDBNum = 4410; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Student Prince (Williams 1968)"                                                             = @{ IPDBNum = 2408; Players = 4; Type = 'EM'; Theme = 'Operetta, Musical' }
    "Sublime (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Punk, Reggae' }
    "Sultan (Taito do Brasil 1979)"                                                              = @{ IPDBNum = 5009; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "Summer Time (Williams 1972)"                                                                = @{ IPDBNum = 2415; Players = 1; Type = 'EM'; Theme = 'Beach, Swimming, Surfing, Water' }
    "Sunset Riders Pinball (Original 2022)"                                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Super Bowl (Bell Games 1984)"                                                               = @{ IPDBNum = 3399; Players = 4; Type = 'SS'; Theme = 'Sports, American Football, Tic-Tac-Toe' }
    "Super Mario Bros. (Gottlieb 1992)"                                                          = @{ IPDBNum = 2435; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed, Kids' }
    "Super Mario Bros. Mushroom World (Gottlieb 1992)"                                           = @{ IPDBNum = 3427; Players = 4; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Super Mario Galaxy Pinball (Original 2020)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Super Nova (Game Plan 1980)"                                                                = @{ IPDBNum = 2436; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Super Orbit (Gottlieb 1983)"                                                                = @{ IPDBNum = 2437; Players = 0; Type = 'SS'; Theme = 'Outer Space' }
    "Super Score (Gottlieb 1967)"                                                                = @{ IPDBNum = 2441; Players = 0; Type = 'EM'; Theme = 'Sports, Pinball' }
    "Super Soccer (Gottlieb 1975)"                                                               = @{ IPDBNum = 2443; Players = 4; Type = 'EM'; Theme = 'Sports, Soccer' }
    "Super Spin (Gottlieb 1977)"                                                                 = @{ IPDBNum = 2445; Players = 2; Type = 'EM'; Theme = 'Fantasy, Recreation' }
    "Super Star (Chicago Coin 1975)"                                                             = @{ IPDBNum = 2447; Players = 4; Type = 'EM'; Theme = 'Olympic Games, Sports' }
    "Super Star (Williams 1972)"                                                                 = @{ IPDBNum = 2446; Players = 1; Type = 'EM'; Theme = 'Music, Singing' }
    "Super Straight (Sonic 1977)"                                                                = @{ IPDBNum = 2449; Players = 4; Type = 'EM'; Theme = 'Cards, Poker, Gambling' }
    "Super-Flite (Williams 1974)"                                                                = @{ IPDBNum = 2452; Players = 2; Type = 'EM'; Theme = 'Aviation, Outer Space' }
    "Superman - The Animated Series - PuP-Pack Edition (Original 2020)"                          = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Comics, Superheroes' }
    "Superman - The Animated Series (Original 2020)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Comics, Superheroes' }
    "Superman (Atari 1979)"                                                                      = @{ IPDBNum = 2454; Players = 4; Type = 'SS'; Theme = 'Fictional, Licensed Theme, Comics, Superheroes' }
    "Superman and The Justice League (Original 2024)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Supersonic (Bally 1979)"                                                                    = @{ IPDBNum = 2455; Players = 4; Type = 'SS'; Theme = 'Aircraft, Historical, Travel' }
    "Supertramp Show (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Supreme Dance Mix (Original 2025)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Sure Shot (Gottlieb 1976)"                                                                  = @{ IPDBNum = 2457; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Sure Shot (Taito do Brasil 1981)"                                                           = @{ IPDBNum = 4574; Players = 4; Type = 'SS'; Theme = 'Billiards' }
    "Surf ''n Safari (Gottlieb 1991)"                                                            = @{ IPDBNum = 2461; Players = 4; Type = 'SS'; Theme = 'Amusement Park, Aquatic, Safari' }
    "Surf Champ (Gottlieb 1976)"                                                                 = @{ IPDBNum = 2459; Players = 4; Type = 'EM'; Theme = 'Sports, Aquatic, Happiness, Recreation, Surfing, Swimming' }
    "Surf Side (Gottlieb 1967)"                                                                  = @{ IPDBNum = 2464; Players = 2; Type = 'EM'; Theme = 'Nautical, Swimming, Sports, Happiness, Aquatic' }
    "Surfer (Gottlieb 1976)"                                                                     = @{ IPDBNum = 2465; Players = 2; Type = 'EM'; Theme = 'Sports, Aquatic, Happiness, Recreation, Surfing, Swimming' }
    "Swamp Thing - Bayou Edition (Original 2024)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Superheroes, Supernatural' }
    "Swamp Thing (Original 2024)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Superheroes, Supernatural' }
    "Swashbuckler (Recel 1979)"                                                                  = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = 'Historical Characters' }
    "Sweet Hearts (Gottlieb 1963)"                                                               = @{ IPDBNum = 2474; Players = 1; Type = 'EM'; Theme = 'Gambling, Cards' }
    "Sweet Sioux (Gottlieb 1959)"                                                                = @{ IPDBNum = 2475; Players = 0; Type = 'EM'; Theme = 'Native Americans' }
    "Swing-Along (Gottlieb 1963)"                                                                = @{ IPDBNum = 2484; Players = 2; Type = 'EM'; Theme = 'Music, Dancing' }
    "Swinger (Williams 1972)"                                                                    = @{ IPDBNum = 2485; Players = 2; Type = 'EM'; Theme = 'Music, Dancing, People, Singing' }
    "Sword Dancer (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy' }
    "Sword of Fury, The (Original 2019)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Medieval, Knights' }
    "Swords of Fury (Williams 1988)"                                                             = @{ IPDBNum = 2486; Players = 4; Type = 'SS'; Theme = 'Fantasy, Knights, Wizards, Magic, Medieval' }
    "T and C Surf (Original 2023)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "T-Rex (Original 2019)"                                                                      = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "T.K.O. (Gottlieb 1979)"                                                                     = @{ IPDBNum = 4599; Players = 1; Type = 'EM'; Theme = 'Sports, Boxing' }
    "Table Starter (Original 2019)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Educational, Example, Testing' }
    "Table With The Least Comprehensible Theme Ever, The (Original 2018)"                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Tag-Team Pinball (Gottlieb 1985)"                                                           = @{ IPDBNum = 2489; Players = 4; Type = 'SS'; Theme = 'Wrestling' }
    "Tales from the Crypt (Data East 1993)"                                                      = @{ IPDBNum = 2493; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Comics, Horror' }
    "Tales of the Arabian Nights (Williams 1996)"                                                = @{ IPDBNum = 3824; Players = 4; Type = 'SS'; Theme = 'Fantasy, Mythology' }
    "Talk Talk (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Talking Word Clock (Original 2020)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Talking Clock' }
    "Tam-Tam (Playmatic 1975)"                                                                   = @{ IPDBNum = 2496; Players = 1; Type = 'EM'; Theme = 'World Culture' }
    "Tango & Cash (Original 2019)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Target Alpha (Gottlieb 1976)"                                                               = @{ IPDBNum = 2500; Players = 4; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Target Pool (Gottlieb 1969)"                                                                = @{ IPDBNum = 2502; Players = 1; Type = 'EM'; Theme = 'Billiards' }
    "Target Practice (Original 2024)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Tarzan - Lex Barker Tribute Edition (Original 2023)"                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fictional Characters' }
    "Taxi - Lola Edition (Williams 1988)"                                                        = @{ IPDBNum = 2505; Players = 4; Type = 'SS'; Theme = 'Cars, Transportation' }
    "Taxi (Williams 1988)"                                                                       = @{ IPDBNum = 2505; Players = 4; Type = 'SS'; Theme = 'Cars, Transportation' }
    "Taxi Driver (Original 2024)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie' }
    "Taylor Swift (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Taylor Swift Eras Tour Pinball (Original 2024)"                                             = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Music' }
    "Teacher''s Pet (Williams 1965)"                                                             = @{ IPDBNum = 2506; Players = 1; Type = 'EM'; Theme = 'Happiness, School' }
    "Team America World Police (Original 2017)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Comedy' }
    "Team One (Gottlieb 1977)"                                                                   = @{ IPDBNum = 2507; Players = 1; Type = 'EM'; Theme = 'Sports, Soccer' }
    "Tee''d Off (Gottlieb 1993)"                                                                 = @{ IPDBNum = 2508; Players = 4; Type = 'SS'; Theme = 'Sports, Golf' }
    "Teenage Mutant Ninja Turtles - PuP-Pack Edition (Data East 1991)"                           = @{ IPDBNum = 2509; Players = 4; Type = 'SS'; Theme = 'Comics, Movie, Kids' }
    "Teenage Mutant Ninja Turtles (Data East 1991)"                                              = @{ IPDBNum = 2509; Players = 4; Type = 'SS'; Theme = 'Comics, Movie, Kids' }
    "Teenage Mutant Ninja Turtles (Stern / Data East remix) (Original 2024)"                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Teenage Mutant Ninja Turtles Remix (Original 2021)"                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = '' }
    "Ten Stars (Zaccaria 1976)"                                                                  = @{ IPDBNum = 3373; Players = 1; Type = 'EM'; Theme = 'Outer Space, Fantasy' }
    "Ten Strike Classic (Benchmark Games 2003)"                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Arcade, Bowling' }
    "Tenacious D (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Terminator 2 - Judgment Day - Chrome Edition (Williams 1991)"                               = @{ IPDBNum = 2524; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie, Apocalyptic' }
    "Terminator 2 - Judgment Day (Williams 1991)"                                                = @{ IPDBNum = 2524; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Movie, Apocalyptic' }
    "Terminator 3 - Rise of the Machines (Stern 2003)"                                           = @{ IPDBNum = 4787; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie, Apocalyptic, Time Travel, Robots' }
    "Terminator Genisys (Original 2019)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Robots, Science Fiction, Time Travel' }
    "Terminator Salvation (Original 2018)"                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction, Apocalyptic' }
    "Terminator, The (Original 2019)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Movie, Science Fiction, Apocalyptic' }
    "Terrific Lake (Sport matic 1987)"                                                           = @{ IPDBNum = 5289; Players = 4; Type = 'SS'; Theme = 'Horror' }
    "Terrifier - Streamer Friendly Edition (Original 2024)"                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Halloween, Horror, Movie' }
    "Terrifier (Original 2024)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Halloween, Horror, Movie' }
    "Test Pilots (Original 2024)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Pilots, Anime, Kids' }
    "Texas Chainsaw Massacre, The (Original 2020)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Horror' }
    "Texas Poker (Original 2019)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Poker' }
    "Texas Ranger (Gottlieb 1972)"                                                               = @{ IPDBNum = 2527; Players = 1; Type = 'EM'; Theme = 'American West, Law Enforcement' }
    "The Legend Of Zelda Twilight Princess (Original 2025)"                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Video Game, Kids' }
    "Theatre of Houdini (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Show Business, Magic' }
    "Theatre of Magic (Bally 1995)"                                                              = @{ IPDBNum = 2845; Players = 4; Type = 'SS'; Theme = 'Show Business, Magic' }
    "They Live (Original 2023)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Science Fiction, Horror, Aliens' }
    "Thornley (Original 2025)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock' }
    "Three Angels (Original 2018)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy' }
    "Thunder Man (Apple Time 1987)"                                                              = @{ IPDBNum = 4666; Players = 4; Type = 'SS'; Theme = 'Adventure, Fictional' }
    "Thunderbirds - Are Go! (Original 2022)"                                                     = @{ IPDBNum = 6617; Players = 0; Type = 'SS'; Theme = 'Adventure, Aviation, Science Fiction, TV Show, Kids' }
    "Thunderbirds (Original 2022)"                                                               = @{ IPDBNum = 6617; Players = 0; Type = 'SS'; Theme = 'Adventure, Aviation, Science Fiction, TV Show, Kids' }
    "Thundercats Pinball (Original 2023)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Animation, Kids' }
    "Ticket Tac Toe (Williams 1996)"                                                             = @{ IPDBNum = 4334; Players = 1; Type = 'SS'; Theme = 'Children''s Games, Kids' }
    "Tidal Wave (Gottlieb 1981)"                                                                 = @{ IPDBNum = 5326; Players = 4; Type = 'SS'; Theme = '' }
    "Tiger (Gottlieb 1975)"                                                                      = @{ IPDBNum = 2560; Players = 1; Type = 'EM'; Theme = 'Circus' }
    "Tiger King (Original 2020)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show' }
    "Tiki Bob''s Atomic Beach Party (Original 2021)"                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Aliens' }
    "Tiki Bob''s Swingin'' Holiday Soiree (Original 2022)"                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Christmas' }
    "Tiki Time (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Happiness, Food' }
    "Time Fantasy (Williams 1983)"                                                               = @{ IPDBNum = 2563; Players = 4; Type = 'SS'; Theme = 'Fantasy, Time Travel' }
    "Time Line (Gottlieb 1980)"                                                                  = @{ IPDBNum = 2564; Players = 4; Type = 'SS'; Theme = 'Adventure, Fantasy, Time Travel' }
    "Time Lord (Original 2022)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Time Travel' }
    "Time Machine (Data East 1988)"                                                              = @{ IPDBNum = 2565; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Time Travel' }
    "Time Machine (LTD do Brasil 1984)"                                                          = @{ IPDBNum = 5887; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Time Travel' }
    "Time Machine (Zaccaria 1983)"                                                               = @{ IPDBNum = 3494; Players = 4; Type = 'SS'; Theme = 'Adventure, Fantasy, Science Fiction, Time Travel' }
    "Time Traveler (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Time Travel' }
    "Time Tunnel (Bally 1971)"                                                                   = @{ IPDBNum = 2566; Players = 4; Type = 'EM'; Theme = 'TV Show, Fantasy, Time Travel' }
    "Time Warp (Williams 1979)"                                                                  = @{ IPDBNum = 2568; Players = 4; Type = 'SS'; Theme = 'Mythology, Science Fiction, Time Travel' }
    "Timon & Pumbaa''s Jungle Pinball (Original 2021)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids' }
    "Tiro''s (Maresa 1969)"                                                                      = @{ IPDBNum = 5818; Players = 1; Type = 'EM'; Theme = 'Amusement Park' }
    "Titan (Gottlieb 1982)"                                                                      = @{ IPDBNum = 5330; Players = 4; Type = 'SS'; Theme = '' }
    "Titan (Taito do Brasil 1981)"                                                               = @{ IPDBNum = 4587; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Titan Music (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Title Fight (Gottlieb 1990)"                                                                = @{ IPDBNum = 2573; Players = 4; Type = 'SS'; Theme = 'Sports, Boxing' }
    "TMNT (Original 2020)"                                                                       = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "Toledo (Williams 1975)"                                                                     = @{ IPDBNum = 2577; Players = 2; Type = 'EM'; Theme = 'World Places' }
    "Tom & Jerry (Original 2018)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Cartoon, Kids' }
    "Tom Petty (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Tomb Raider - A Survival is Born (Original 2019)"                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Tomb Raider (Original 2025)"                                                                = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Action, Adventure' }
    "Tommy Boy (Original 2021)"                                                                  = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Movie' }
    "Tool (Original 2020)"                                                                       = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Heavy Metal' }
    "Top Card (Gottlieb 1974)"                                                                   = @{ IPDBNum = 2580; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Top Dawg (Williams 1988)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Arcade, Bowling, Flipperless' }
    "Top Gun (Original 2019)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Aviation, Movie' }
    "Top Hand (Gottlieb 1973)"                                                                   = @{ IPDBNum = 2582; Players = 1; Type = 'EM'; Theme = 'Cards, Gambling' }
    "Top of the Pops Xmas Pinball (Original 2020)"                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Christmas, Music' }
    "Top Score (Gottlieb 1975)"                                                                  = @{ IPDBNum = 2589; Players = 2; Type = 'EM'; Theme = 'Sports, Bowling' }
    "Topaz (Inder 1979)"                                                                         = @{ IPDBNum = 4477; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy, Women' }
    "Torch (Gottlieb 1980)"                                                                      = @{ IPDBNum = 2595; Players = 4; Type = 'SS'; Theme = 'Sports, Olympic Games' }
    "Tornado Rally (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = '' }
    "Torpedo Alley (Data East 1988)"                                                             = @{ IPDBNum = 2603; Players = 4; Type = 'SS'; Theme = 'Adventure, Combat, Nautical' }
    "Torpedo!! (Petaco 1976)"                                                                    = @{ IPDBNum = 4371; Players = 1; Type = 'EM'; Theme = 'Adventure, Combat, Nautical' }
    "Total Nuclear Annihilation - Welcome to the Future Edition (Spooky Pinball 2017)"           = @{ IPDBNum = 6444; Players = 4; Type = 'SS'; Theme = 'Combat, Science Fiction, Apocalyptic' }
    "Total Nuclear Annihilation (Spooky Pinball 2017)"                                           = @{ IPDBNum = 6444; Players = 4; Type = 'SS'; Theme = 'Combat, Science Fiction, Apocalyptic' }
    "Totem (Gottlieb 1979)"                                                                      = @{ IPDBNum = 2607; Players = 4; Type = 'SS'; Theme = 'American West, Native Americans' }
    "TOTO (Original 2025)"                                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock, Progressive, Pop' }
    "Touchdown (Gottlieb 1984)"                                                                  = @{ IPDBNum = 2610; Players = 4; Type = 'SS'; Theme = 'Sports, American Football' }
    "Touchdown (Williams 1967)"                                                                  = @{ IPDBNum = 2609; Players = 1; Type = 'EM'; Theme = 'Sports, American Football' }
    "Toxic Tattoo (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Toy Story 90s Pinball (Original 2024)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Trade Winds (Williams 1962)"                                                                = @{ IPDBNum = 2621; Players = 1; Type = 'EM'; Theme = 'Boats, Nautical, Aquatic' }
    "Trailer (Playmatic 1985)"                                                                   = @{ IPDBNum = 3276; Players = 4; Type = 'SS'; Theme = 'Travel, Transportation, Truck Driving' }
    "Trailer Park Boys - Pin-Ballers (Original 2024)"                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'TV Show, Comedy' }
    "Tramway (Williams 1973)"                                                                    = @{ IPDBNum = 2627; Players = 2; Type = 'EM'; Theme = 'Travel, Tramways, Transportation' }
    "Transformers - The Movie 1986 (Original 2019)"                                              = @{ IPDBNum = 0; Players = 2; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Transformers (Pro) (Stern 2011)"                                                            = @{ IPDBNum = 5709; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Science Fiction, Movie, Robots' }
    "Transformers G1 (Original 2018)"                                                            = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Transporter the Rescue (Bally 1989)"                                                        = @{ IPDBNum = 2630; Players = 4; Type = 'SS'; Theme = 'Outer Space' }
    "Travel Time (Williams 1972)"                                                                = @{ IPDBNum = 2636; Players = 1; Type = 'EM'; Theme = 'Beach, Swimming, Surfing, Travel, Water' }
    "Treff (Walter Steiner 1949)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'PM'; Theme = 'Flipperless' }
    "Tri Zone (Williams 1979)"                                                                   = @{ IPDBNum = 2641; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Trials of Kaladon (Original 2021)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Mythology, Fantasy' }
    "Trick ''r Treat (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie' }
    "Trick Shooter (LTD do Brasil 1980)"                                                         = @{ IPDBNum = 5888; Players = 0; Type = 'SS'; Theme = 'American West' }
    "Trident (Stern 1979)"                                                                       = @{ IPDBNum = 2644; Players = 4; Type = 'SS'; Theme = 'Mythology' }
    "Triple Action (Williams 1973)"                                                              = @{ IPDBNum = 2648; Players = 1; Type = 'EM'; Theme = 'Show Business' }
    "Triple Strike (Williams 1975)"                                                              = @{ IPDBNum = 2652; Players = 1; Type = 'EM'; Theme = 'Sports, Bowling' }
    "Triple X (Williams 1973)"                                                                   = @{ IPDBNum = 6497; Players = 2; Type = 'EM'; Theme = 'Board Games, Tic-Tac-Toe' }
    "Tripping Tractors (Original 2025)"                                                          = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Tractors, LSD' }
    "Triumph (Original 2021)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "TRON Classic - PuP-Pack Edition (Original 2018)"                                            = @{ IPDBNum = 1745; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "TRON Classic (Original 2018)"                                                               = @{ IPDBNum = 1745; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "TRON Neon (Original 2024)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Science Fiction, Movie' }
    "Tropic Fun (Williams 1973)"                                                                 = @{ IPDBNum = 2660; Players = 1; Type = 'EM'; Theme = 'Beach, Recreation, Water' }
    "Truck Stop (Bally 1988)"                                                                    = @{ IPDBNum = 2667; Players = 4; Type = 'SS'; Theme = 'American Places, Travel, Transportation, Truck Driving' }
    "Turrican (Original 2018)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Twilight Zone - B&W Edition (Bally 1993)"                                                   = @{ IPDBNum = 2684; Players = 4; Type = 'SS'; Theme = 'Adventure, Supernatural, Licensed Theme, TV Show' }
    "Twilight Zone (Bally 1993)"                                                                 = @{ IPDBNum = 2684; Players = 4; Type = 'SS'; Theme = 'Adventure, Supernatural, Licensed Theme, TV Show' }
    "Twin Peaks - Remix Edition (Original 2022)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Twin Peaks (Original 2022)"                                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show, Crime' }
    "Twinky (Chicago Coin 1967)"                                                                 = @{ IPDBNum = 2692; Players = 2; Type = 'EM'; Theme = 'Modeling, Television' }
    "Twisted Metal (Original 2024)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Apocalyptic, Auto Racing, Video Game, TV Show' }
    "Twister (Sega 1996)"                                                                        = @{ IPDBNum = 3976; Players = 6; Type = 'SS'; Theme = 'Movie, Licensed Theme, Weather' }
    "TX-Sector (Gottlieb 1988)"                                                                  = @{ IPDBNum = 2699; Players = 4; Type = 'SS'; Theme = 'Outer Space, Science Fiction' }
    "Tyrannosaurus (Gottlieb 1985)"                                                              = @{ IPDBNum = 5344; Players = 4; Type = 'SS'; Theme = '' }
    "U-Boat 65 (Nuova Bell Games 1988)"                                                          = @{ IPDBNum = 3736; Players = 4; Type = 'SS'; Theme = 'Combat, Nautical' }
    "U-FOES (Original 2019)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Comics' }
    "U2 (Original 2024)"                                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "U2 360 (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "U2 Reskin (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "UB40 (Original 2025)"                                                                       = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music' }
    "Ultron (Original 2022)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Underwater (Recel 1976)"                                                                    = @{ IPDBNum = 2702; Players = 4; Type = 'EM'; Theme = 'Adventure, Combat, Nautical' }
    "Unicorcs (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Universe (Gottlieb 1959)"                                                                   = @{ IPDBNum = 2705; Players = 1; Type = 'EM'; Theme = 'Outer Space' }
    "Universe (Zaccaria 1976)"                                                                   = @{ IPDBNum = 2706; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Unreal Tournament 99 Capture the Flag (Original 2021)"                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Untouchables, The (Original 2023)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie, Crime, Mobsters, Detective' }
    "V.1 (IDSA 1986)"                                                                            = @{ IPDBNum = 5022; Players = 4; Type = 'SS'; Theme = 'Outer Space, Fantasy' }
    "Vampire (Bally 1971)"                                                                       = @{ IPDBNum = 2716; Players = 2; Type = 'EM'; Theme = 'Vampires' }
    "Vampirella (Original 2024)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Comics, Horror' }
    "Van Halen (Original 2020)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Van Halen (Original 2025)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music' }
    "Vasco da Gama (Original 2020)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Historical' }
    "Vector (Bally 1982)"                                                                        = @{ IPDBNum = 2723; Players = 4; Type = 'SS'; Theme = 'Fantasy, Sports' }
    "Vector Pinball (Field One) (Dozing Cat Software 2010)"                                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = '' }
    "Vegas (Gottlieb 1990)"                                                                      = @{ IPDBNum = 2724; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "Vegas (Taito do Brasil 1980)"                                                               = @{ IPDBNum = 4575; Players = 4; Type = 'SS'; Theme = 'Gambling' }
    "Verne''s World (Spinball S.A.L. 1996)"                                                      = @{ IPDBNum = 4619; Players = 4; Type = 'SS'; Theme = 'Adventure, Fantasy, Fictional' }
    "Victory (Gottlieb 1987)"                                                                    = @{ IPDBNum = 2733; Players = 4; Type = 'SS'; Theme = 'Sports, Auto Racing' }
    "Viking (Bally 1980)"                                                                        = @{ IPDBNum = 2737; Players = 4; Type = 'SS'; Theme = 'Norse Mythology, Historical' }
    "Viking King (LTD do Brasil 1979)"                                                           = @{ IPDBNum = 5895; Players = 2; Type = 'SS'; Theme = 'Norse Mythology' }
    "Vikings (Original 2022)"                                                                    = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'TV Show, Norse Mythology' }
    "Viper (Stern 1981)"                                                                         = @{ IPDBNum = 2739; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Viper Night Drivin'' (Sega 1998)"                                                           = @{ IPDBNum = 4359; Players = 6; Type = 'SS'; Theme = 'Cars, Licensed Theme, Auto Racing' }
    "Volcano (Gottlieb 1981)"                                                                    = @{ IPDBNum = 2742; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Volkan Steel and Metal (Original 2023)"                                                     = @{ IPDBNum = 0; Players = 2; Type = 'SS'; Theme = 'Steampunk' }
    "Volley (Gottlieb 1976)"                                                                     = @{ IPDBNum = 2743; Players = 1; Type = 'EM'; Theme = 'Sports, Tennis' }
    "Volley (Taito do Brasil 1981)"                                                              = @{ IPDBNum = 5494; Players = 4; Type = 'SS'; Theme = 'Sports, Volleyball' }
    "Voltan Escapes Cosmic Doom (Bally 1979)"                                                    = @{ IPDBNum = 2744; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Voodoo Ranger (Original 2025)"                                                              = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Alcohol, Beer' }
    "VooDoo''s Carnival Pinball (Original 2022)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Supernatural, Occult, Carnival' }
    "Vortex (Taito do Brasil 1983)"                                                              = @{ IPDBNum = 4576; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Vortex Plunder (Original 2025)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Psychedelic' }
    "VPin Workshop Example & Resource Table (Original 2021)"                                     = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Educational, Example, Testing' }
    "VPX Foosball 2019 (Original 2019)"                                                          = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Sports, Soccer' }
    "VR Clean Room with Tutorial (Original 2020)"                                                = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Educational, Tutorial' }
    "VR Room Educational Toyboy (Original 2020)"                                                 = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Educational, Example, Testing' }
    "Vulcan (Gottlieb 1977)"                                                                     = @{ IPDBNum = 2745; Players = 4; Type = 'EM'; Theme = 'Roman Mythology' }
    "Vulcan IV (Rowamet 1982)"                                                                   = @{ IPDBNum = 5169; Players = 4; Type = 'SS'; Theme = 'Mythology' }
    "Wacky Races (Original 2022)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, Auto Racing' }
    "Wade Wilson (Original 2019)"                                                                = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Wailing Asteroid - Murray Leinster, The (Original 2024)"                                    = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Science Fiction' }
    "Walking Dead (Limited Edition), The (Stern 2014)"                                           = @{ IPDBNum = 6156; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Supernatural, Zombies, TV Show, Horror' }
    "Walking Dead (Pro), The (Stern 2014)"                                                       = @{ IPDBNum = 6155; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Supernatural, Zombies, TV Show, Horror' }
    "Walking Dead, The (Original 2016)"                                                          = @{ IPDBNum = 0; Players = 1; Type = 'SS'; Theme = '' }
    "Walkure (Original 2025)"                                                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Anime, Kids' }
    "Walkyria (Joctronic 1986)"                                                                  = @{ IPDBNum = 5556; Players = 4; Type = 'SS'; Theme = 'Norse Mythology' }
    "Wallace And Gromit (Original 2006)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Animation, Kids' }
    "Warlok (Williams 1982)"                                                                     = @{ IPDBNum = 2754; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Warrior Sea (Electromatic 1977)"                                                            = @{ IPDBNum = 0; Players = 0; Type = ''; Theme = '' }
    "Warriors, The (Original 2023)"                                                              = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Watchmen (Original 2019)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Comics, Superheroes' }
    "Waterworld (Gottlieb 1995)"                                                                 = @{ IPDBNum = 3793; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, Movie, Apocalyptic' }
    "Way of the Dragon, The (Original 2020)"                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Martial Arts' }
    "Wayne''s World (Original 2020)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Music, Movie' }
    "Wednesday (Original 2023)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Wheel (Maresa 1974)"                                                                        = @{ IPDBNum = 4644; Players = 1; Type = 'EM'; Theme = 'Sports, Auto Racing, Cars' }
    "Wheel of Fortune (Stern 2007)"                                                              = @{ IPDBNum = 5254; Players = 4; Type = 'SS'; Theme = 'Licensed Theme, TV Show, Game Show' }
    "Whirl-Wind (Gottlieb 1958)"                                                                 = @{ IPDBNum = 2760; Players = 2; Type = 'EM'; Theme = 'Dancing' }
    "Whirlwind (Williams 1990)"                                                                  = @{ IPDBNum = 2765; Players = 4; Type = 'SS'; Theme = 'Adventure, Weather' }
    "White Christmas (Original 2023)"                                                            = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Music, Caroling, Christmas' }
    "White Water (Williams 1993)"                                                                = @{ IPDBNum = 2768; Players = 4; Type = 'SS'; Theme = 'Sports, Rafting, Aquatic, Mythology' }
    "Whitesnake (Original 2025)"                                                                 = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music, Rock' }
    "WHO dunnit (Bally 1995)"                                                                    = @{ IPDBNum = 3685; Players = 4; Type = 'SS'; Theme = 'Detective, Crime' }
    "Who Framed Roger Rabbit (Original 2021)"                                                    = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Animation, Kids, Movie' }
    "Who''s Tommy Pinball Wizard, The (Data East 1994)"                                          = @{ IPDBNum = 2579; Players = 4; Type = 'SS'; Theme = 'Celebrities, Fictional, Licensed Theme, Musical, Movie, Rock n roll' }
    "Whoa Nellie! Big Juicy Melons - Nude Edition (Stern 2015)"                                  = @{ IPDBNum = 6252; Players = 4; Type = 'SS'; Theme = 'Agriculture, Fantasy, Women, Adult' }
    "Whoa Nellie! Big Juicy Melons (Stern 2015)"                                                 = @{ IPDBNum = 6252; Players = 4; Type = 'SS'; Theme = 'Agriculture, Fantasy, Women, Adult' }
    "Whoa Nellie! Big Juicy Melons (WhizBang Pinball 2011)"                                      = @{ IPDBNum = 5863; Players = 1; Type = 'EM'; Theme = 'Agriculture, Fantasy, Women' }
    "Wiedzmin (Original 2024)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Fantasy, Adventure, TV Show, Video Game' }
    "Wiggler, The (Bally 1967)"                                                                  = @{ IPDBNum = 2777; Players = 4; Type = 'EM'; Theme = 'Fantasy' }
    "Wild Card (Williams 1977)"                                                                  = @{ IPDBNum = 2778; Players = 1; Type = 'EM'; Theme = 'American West, Cards, Gambling' }
    "Wild Fyre (Stern 1978)"                                                                     = @{ IPDBNum = 2783; Players = 4; Type = 'SS'; Theme = 'Historical, Chariot Racing, Roman History' }
    "Wild Life (Gottlieb 1972)"                                                                  = @{ IPDBNum = 2784; Players = 2; Type = 'EM'; Theme = 'Jungle' }
    "Wild West (Original 2024)"                                                                  = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Country and Western' }
    "Wild Wild West (Gottlieb 1969)"                                                             = @{ IPDBNum = 2787; Players = 2; Type = 'EM'; Theme = 'American West' }
    "Wild Wild West, The (Original 2022)"                                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'TV Show' }
    "Willow (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy, Movie' }
    "Willy Wonka & the Chocolate Factory - Limited Edition (Original 2020)"                      = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Willy Wonka & the Chocolate Factory - PuP-Pack Edition (Original 2020)"                     = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Willy Wonka & the Chocolate Factory (Original 2020)"                                        = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Willy''s Wonderland (Original 2021)"                                                        = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Movie, Horror' }
    "Wimbledon (Electromatic 1978)"                                                              = @{ IPDBNum = 6581; Players = 1; Type = 'EM'; Theme = 'Sports, Tennis' }
    "Winner (Williams 1971)"                                                                     = @{ IPDBNum = 2792; Players = 2; Type = 'EM'; Theme = 'Sports, Horse Racing' }
    "Wipe Out (Gottlieb 1993)"                                                                   = @{ IPDBNum = 2799; Players = 4; Type = 'SS'; Theme = 'Sports, Skiing' }
    "Witcher, The (Original 2020)"                                                               = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy, Video Game, TV Show' }
    "Wizard, The (Original 2021)"                                                                = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Movie, Kids, Video Game' }
    "Wizard! (Bally 1975)"                                                                       = @{ IPDBNum = 2803; Players = 4; Type = 'EM'; Theme = 'Licensed Theme' }
    "Wolf Man (Peyper 1987)"                                                                     = @{ IPDBNum = 4435; Players = 4; Type = 'SS'; Theme = 'Mythology, Horror' }
    "Wolfenstein 3D (Original 2015)"                                                             = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Video Game' }
    "Wonderland (Williams 1955)"                                                                 = @{ IPDBNum = 2805; Players = 1; Type = 'EM'; Theme = 'Fictional, Fantasy' }
    "Woodcutter, The (Original 2025)"                                                            = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Outdoor Activities' }
    "Woody Woodpecker (Original 2022)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Animation, Kids' }
    "World Challenge Soccer (Gottlieb 1994)"                                                     = @{ IPDBNum = 2808; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "World Cup (Williams 1978)"                                                                  = @{ IPDBNum = 2810; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "World Cup Soccer (Bally 1994)"                                                              = @{ IPDBNum = 2811; Players = 4; Type = 'SS'; Theme = 'Sports, Soccer' }
    "World Poker Tour (Stern 2006)"                                                              = @{ IPDBNum = 5134; Players = 4; Type = 'SS'; Theme = 'Gambling, Cards, Poker, Licensed Theme' }
    "World Series (Gottlieb 1972)"                                                               = @{ IPDBNum = 2813; Players = 1; Type = 'EM'; Theme = 'Sports, Baseball' }
    "World''s Fair Jig-Saw (Rock-ola 1933)"                                                      = @{ IPDBNum = 1295; Players = 1; Type = 'PM'; Theme = 'Celebration' }
    "WoZ - Yellow Brick Road Limited Edition (Original 2018)"                                    = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy, Wizards, Magic' }
    "WoZ (Original 2018)"                                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Fantasy, Wizards, Magic' }
    "WWF Royal Rumble (Data East 1994)"                                                          = @{ IPDBNum = 2820; Players = 4; Type = 'SS'; Theme = 'Licensed, Sports, Wrestling, Comedy, Licensed Theme' }
    "X Files, The (Original 2021)"                                                               = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Science Fiction, TV Show' }
    "X Files, The (Sega 1997)"                                                                   = @{ IPDBNum = 4137; Players = 6; Type = 'SS'; Theme = 'Aliens, Conspiracy, Supernatural, Licensed, TV Show' }
    "X-Men Magneto LE (Stern 2012)"                                                              = @{ IPDBNum = 5823; Players = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes' }
    "X-Men Wolverine LE (Stern 2012)"                                                            = @{ IPDBNum = 5824; Players = 4; Type = 'SS'; Theme = 'Comics, Fantasy, Licensed Theme, Superheroes' }
    "X''s & O''s (Bally 1984)"                                                                   = @{ IPDBNum = 2822; Players = 4; Type = 'SS'; Theme = 'Board Games, Tic-Tac-Toe' }
    "Xenon (Bally 1980)"                                                                         = @{ IPDBNum = 2821; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Yamanobori (Komaya 1981)"                                                                   = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Mountain Climbing, Flipperless' }
    "Yello Pinball Cha Cha (Original 2021)"                                                      = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Electronic Music' }
    "Yellow Submarine (Original 2020)"                                                           = @{ IPDBNum = 0; Players = 4; Type = 'EM'; Theme = 'Music' }
    "Yes (Original 2025)"                                                                        = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Progressive, Pop' }
    "You’ll Shoot Your Eye Out! (Original 2024)"                                                 = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Christmas, Movie, Kids' }
    "Young Frankenstein (Original 2016)"                                                         = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Movie' }
    "Young Frankenstein (Original 2021)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Movie, Comedy' }
    "Young Frankenstein (Original 2025)"                                                         = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Horror, Movie, Comedy' }
    "Yukon (Special) (Williams 1971)"                                                            = @{ IPDBNum = 3533; Players = 1; Type = 'EM'; Theme = 'Canadian West' }
    "Yukon (Williams 1971)"                                                                      = @{ IPDBNum = 2829; Players = 0; Type = 'EM'; Theme = 'Canadian West' }
    "Zarza (Taito do Brasil 1982)"                                                               = @{ IPDBNum = 4584; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Zeke''s Peak (Taito 1984)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Mountain Climbing, Flipperless' }
    "Zephy (LTD do Brasil 1982)"                                                                 = @{ IPDBNum = 4592; Players = 3; Type = 'SS'; Theme = 'Fantasy' }
    "Zip-A-Doo (Bally 1970)"                                                                     = @{ IPDBNum = 2840; Players = 2; Type = 'EM'; Theme = 'Happiness, Flower Power' }
    "Zira (Playmatic 1980)"                                                                      = @{ IPDBNum = 3584; Players = 4; Type = 'SS'; Theme = 'Fantasy' }
    "Zissou - The Life Aquatic (Original 2022)"                                                  = @{ IPDBNum = 0; Players = 1; Type = 'EM'; Theme = 'Movie, Aquatic, Nautical' }
    "Zodiac (Williams 1971)"                                                                     = @{ IPDBNum = 2841; Players = 2; Type = 'EM'; Theme = 'Astrology' }
    "Zonderik Pinball (Belgamko 2010)"                                                           = @{ IPDBNum = 0; Players = 0; Type = 'SS'; Theme = 'Drinking' }
    "Zone Fury (Original 2023)"                                                                  = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Futuristic Racing, Video Game' }
    "ZZ Top (Original 2021)"                                                                     = @{ IPDBNum = 0; Players = 0; Type = 'EM'; Theme = 'Music, Rock n roll' }
    "ZZ Top (Original 2025)"                                                                     = @{ IPDBNum = 0; Players = 4; Type = 'SS'; Theme = 'Music, Rock n roll' }
}

# =============================================================================
# Table ratings

function Get-IpdbRatings {
    Param([string]$Path = ".\puplookup.csv")
    '$script:ipdbRatings = @{'
    foreach ($e in (Import-Csv $Path | Sort-Object -Unique GameName)) {
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

            if ($result.StatusCode -eq 200) {
                $html = $result.Content
                if ($html -match '<b>Average Fun Rating: <\/b>.*<b>(?<rating>.+)<\/b>\/10') {
                    '  "{0}" =  {1}' -f ($e.GameName -replace '''', ''''''), [double]$matches['rating']
                }
            }
        }
    }
    '}'
}

$script:ipdbRatings = @{
    "''300'' (Gottlieb 1975)"                                                          = 7.4
    "2001 (Gottlieb 1971)"                                                             = 7.6
    "24 (Stern 2009)"                                                                  = 7
    "4 Aces (Williams 1970)"                                                           = 7.2
    "4 Queens (Bally 1970)"                                                            = 7.3
    "4 Roses (Williams 1962)"                                                          = 7.8
    "4 Square (Gottlieb 1971)"                                                         = 7.6
    "8 Ball (Williams 1966)"                                                           = 7.7
    "A-Go-Go (Williams 1966)"                                                          = 7.6
    "Abra Ca Dabra (Gottlieb 1975)"                                                    = 7.8
    "AC/DC (Let There Be Rock Limited Edition) (Stern 2012)"                           = 7.9
    "AC/DC (Premium) (Stern 2012)"                                                     = 8
    "AC/DC (Pro) (Stern 2012)"                                                         = 7.9
    "AC/DC Back In Black (Limited Edition) (Stern 2012)"                               = 7.8
    "Ace High (Gottlieb 1957)"                                                         = 7.6
    "Aces & Kings (Williams 1970)"                                                     = 6.4
    "Addams Family, The - B&W Edition (Bally 1992)"                                    = 8.3
    "Addams Family, The (Bally 1992)"                                                  = 8.3
    "Adventures of Rocky and Bullwinkle and Friends (Data East 1993)"                  = 7.8
    "Aerosmith (Pro) (Stern 2017)"                                                     = 7.9
    "Air Aces (Bally 1975)"                                                            = 6.6
    "Airborne (Capcom 1996)"                                                           = 7.5
    "Airport (Gottlieb 1969)"                                                          = 6.2
    "Al''s Garage Band Goes on a World Tour (Alvin G. 1992)"                           = 6.7
    "Aladdin''s Castle (Bally 1976)"                                                   = 7.6
    "Algar (Williams 1980)"                                                            = 7.1
    "Ali (Stern 1980)"                                                                 = 7.4
    "Alien Poker (Williams 1980)"                                                      = 7.7
    "Aloha (Gottlieb 1961)"                                                            = 7.5
    "Amazing Spider-Man, The - Sinister Six Edition (Gottlieb 1980)"                   = 7.5
    "Amazing Spider-Man, The (Gottlieb 1980)"                                          = 7.5
    "Amazon Hunt (Gottlieb 1983)"                                                      = 7.4
    "America''s Most Haunted (Spooky Pinball 2014)"                                    = 7.4
    "Amigo (Bally 1974)"                                                               = 7.8
    "Andromeda - Tokyo 2074 Edition (Game Plan 1985)"                                  = 7.1
    "Andromeda (Game Plan 1985)"                                                       = 7.1
    "Apollo (Williams 1967)"                                                           = 7.8
    "Apollo 13 (Sega 1995)"                                                            = 7.8
    "Aquarius (Gottlieb 1970)"                                                         = 7.6
    "Arena (Gottlieb 1987)"                                                            = 7.1
    "Argosy (Williams 1977)"                                                           = 6.6
    "Asteroid Annie and the Aliens (Gottlieb 1980)"                                    = 7.1
    "Astro (Gottlieb 1971)"                                                            = 8
    "Atlantis (Bally 1989)"                                                            = 7.3
    "Atlantis (Gottlieb 1975)"                                                         = 7.7
    "Attack from Mars (Bally 1995)"                                                    = 8.2
    "Austin Powers (Stern 2001)"                                                       = 6.7
    "Avengers (Pro), The (Stern 2012)"                                                 = 6.4
    "Aztec - High-Tap Edition (Williams 1976)"                                         = 7.8
    "Aztec (Williams 1976)"                                                            = 7.8
    "Baby Pac-Man (Bally 1982)"                                                        = 6.9
    "Back to the Future (Data East 1990)"                                              = 7.6
    "Bad Cats (Williams 1989)"                                                         = 7.8
    "Bad Girls - Alternate Edition (Gottlieb 1988)"                                    = 6.6
    "Bad Girls - Tooned-Up Version (Gottlieb 1988)"                                    = 6.6
    "Bad Girls (Gottlieb 1988)"                                                        = 6.6
    "Bally Game Show, The (Bally 1990)"                                                = 7.1
    "Bally Hoo (Bally 1969)"                                                           = 7.5
    "Bank Shot (Gottlieb 1976)"                                                        = 7.4
    "Bank-A-Ball (Gottlieb 1965)"                                                      = 7.5
    "Banzai Run (Williams 1988)"                                                       = 7.8
    "Barb Wire (Gottlieb 1996)"                                                        = 7.3
    "Barracora (Williams 1981)"                                                        = 7.5
    "Baseball (Gottlieb 1970)"                                                         = 7.4
    "Batman (66 Premium) (Stern 2016)"                                                 = 8.7
    "Batman (Data East 1991)"                                                          = 7.2
    "Batman (Stern 2008)"                                                              = 8
    "Batman Forever (Sega 1995)"                                                       = 7.8
    "Batter Up (Gottlieb 1970)"                                                        = 7.6
    "Baywatch (Sega 1995)"                                                             = 7.9
    "Beat Time - Beatles Edition (Williams 1967)"                                      = 5.8
    "Beat Time (Williams 1967)"                                                        = 5.8
    "Big Bang Bar (Capcom 1996)"                                                       = 7.3
    "Big Ben (Williams 1975)"                                                          = 6.1
    "Big Brave - B&W Edition (Gottlieb 1974)"                                          = 7.6
    "Big Brave (Gottlieb 1974)"                                                        = 7.6
    "Big Brave (Maresa 1974)"                                                          = 7.5
    "Big Buck Hunter Pro (Stern 2010)"                                                 = 6.7
    "Big Casino (Gottlieb 1961)"                                                       = 6.7
    "Big Chief (Williams 1965)"                                                        = 7.3
    "Big Deal (Williams 1963)"                                                         = 7.4
    "Big Deal (Williams 1977)"                                                         = 7.3
    "Big Game (Stern 1980)"                                                            = 7.3
    "Big Guns (Williams 1987)"                                                         = 7.1
    "Big Hit (Gottlieb 1977)"                                                          = 7.3
    "Big House (Gottlieb 1989)"                                                        = 7.3
    "Big Indian (Gottlieb 1974)"                                                       = 7.8
    "Big Injun (Gottlieb 1974)"                                                        = 7.8
    "Big Shot (Gottlieb 1974)"                                                         = 7.3
    "Big Show (Bally 1974)"                                                            = 5.7
    "Big Valley (Bally 1970)"                                                          = 7.7
    "Black Hole (Gottlieb 1981)"                                                       = 7.8
    "Black Jack (SS) (Bally 1978)"                                                     = 7.3
    "Black Knight (Williams 1980)"                                                     = 8
    "Black Knight 2000 (Williams 1989)"                                                = 7.9
    "Black Pyramid (Bally 1984)"                                                       = 6.8
    "Black Rose (Bally 1992)"                                                          = 8
    "Blackout (Williams 1980)"                                                         = 7.6
    "Blackwater 100 (Bally 1988)"                                                      = 6.7
    "Blue Chip (Williams 1976)"                                                        = 7.5
    "Blue Note (Gottlieb 1978)"                                                        = 7.3
    "Bobby Orr Power Play (Bally 1978)"                                                = 7.5
    "Bon Voyage (Bally 1974)"                                                          = 7
    "Bone Busters Inc. (Gottlieb 1989)"                                                = 7.3
    "Boomerang (Bally 1974)"                                                           = 7.6
    "Bounty Hunter (Gottlieb 1985)"                                                    = 7.1
    "Bow and Arrow (EM) (Bally 1975)"                                                  = 7.6
    "Bram Stoker''s Dracula - Blood Edition (Williams 1993)"                           = 8.1
    "Bram Stoker''s Dracula (Williams 1993)"                                           = 8.1
    "Breakshot (Capcom 1996)"                                                          = 7.3
    "Bronco (Gottlieb 1977)"                                                           = 7.4
    "Buccaneer (Gottlieb 1976)"                                                        = 7.6
    "Buck Rogers (Gottlieb 1980)"                                                      = 7.3
    "Buckaroo (Gottlieb 1965)"                                                         = 7.8
    "Bugs Bunny''s Birthday Ball (Bally 1990)"                                         = 6.9
    "Cactus Canyon (Bally 1998)"                                                       = 8
    "Cactus Jack''s (Gottlieb 1991)"                                                   = 7.3
    "Canada Dry (Gottlieb 1976)"                                                       = 7.3
    "Capersville (Bally 1966)"                                                         = 7.4
    "Capt. Card (Gottlieb 1974)"                                                       = 7.7
    "Capt. Fantastic and the Brown Dirt Cowboy (Bally 1976)"                           = 7.7
    "Car Hop (Gottlieb 1991)"                                                          = 7.6
    "Card Trix (Gottlieb 1970)"                                                        = 7.5
    "Card Whiz (Gottlieb 1976)"                                                        = 7.8
    "Catacomb (Stern 1981)"                                                            = 7.4
    "Caveman (Gottlieb 1982)"                                                          = 6.5
    "Centaur (Bally 1981)"                                                             = 8
    "Centigrade 37 (Gottlieb 1977)"                                                    = 7.8
    "Central Park (Gottlieb 1966)"                                                     = 7.7
    "Champ (Bally 1974)"                                                               = 6.7
    "Champion Pub, The (Bally 1998)"                                                   = 7.8
    "Charlie''s Angels (Gottlieb 1978)"                                                = 6.5
    "Checkpoint (Data East 1991)"                                                      = 7
    "Cheetah (Stern 1980)"                                                             = 7.4
    "Chicago Cubs ''Triple Play'' (Gottlieb 1985)"                                     = 6.9
    "Circus (Bally 1973)"                                                              = 6.4
    "Circus (Gottlieb 1980)"                                                           = 7.2
    "Circus (Zaccaria 1977)"                                                           = 7.1
    "Cirqus Voltaire (Bally 1997)"                                                     = 8.1
    "Class of 1812 (Gottlieb 1991)"                                                    = 7.8
    "Cleopatra (SS) (Gottlieb 1977)"                                                   = 7.4
    "Close Encounters of the Third Kind (Gottlieb 1978)"                               = 7
    "College Queens (Gottlieb 1969)"                                                   = 6.2
    "Comet (Williams 1985)"                                                            = 7.7
    "Congo (Williams 1995)"                                                            = 8
    "Contact (Williams 1978)"                                                          = 7.1
    "Coronation (Gottlieb 1952)"                                                       = 8.1
    "Corvette (Bally 1994)"                                                            = 7.9
    "Cosmic Gunfight (Williams 1982)"                                                  = 7.3
    "Count-Down (Gottlieb 1979)"                                                       = 7.5
    "Counterforce (Gottlieb 1980)"                                                     = 7.6
    "Cow Poke (Gottlieb 1965)"                                                         = 7.7
    "Creature from the Black Lagoon - B&W Edition (Bally 1992)"                        = 8.2
    "Creature from the Black Lagoon - Nude Edition (Bally 1992)"                       = 8.2
    "Creature from the Black Lagoon (Bally 1992)"                                      = 8.2
    "Crescendo (Gottlieb 1970)"                                                        = 6.4
    "Criterium 75 (Recel 1975)"                                                        = 6.6
    "Cross Town (Gottlieb 1966)"                                                       = 7.7
    "CSI (Stern 2008)"                                                                 = 6.7
    "Cue Ball Wizard (Gottlieb 1992)"                                                  = 7.3
    "Cybernaut (Bally 1985)"                                                           = 7
    "Cyclone (Williams 1988)"                                                          = 8
    "Dale Jr. (Stern 2007)"                                                            = 7.2
    "Darling (Williams 1973)"                                                          = 5.5
    "Deadly Weapon (Gottlieb 1990)"                                                    = 7
    "Dealer''s Choice (Williams 1973)"                                                 = 7.3
    "Defender (Williams 1982)"                                                         = 7.4
    "Demolition Man - Limited Cryo Edition (Williams 1994)"                            = 8
    "Demolition Man (Williams 1994)"                                                   = 8
    "Devil Riders (Zaccaria 1984)"                                                     = 7.4
    "Devil''s Dare (Gottlieb 1982)"                                                    = 7.9
    "Diamond Jack (Gottlieb 1967)"                                                     = 7.7
    "Diamond Lady (Gottlieb 1988)"                                                     = 7.4
    "Dimension (Gottlieb 1971)"                                                        = 7.6
    "Diner (Williams 1990)"                                                            = 8
    "Dipsy Doodle (Williams 1970)"                                                     = 6.9
    "Dirty Harry (Williams 1995)"                                                      = 7.5
    "Disco Fever (Williams 1978)"                                                      = 5.9
    "Disney TRON Legacy (Limited Edition) - PuP-Pack Edition (Stern 2011)"             = 7.9
    "Disney TRON Legacy (Limited Edition) (Stern 2011)"                                = 7.9
    "Dixieland (Bally 1968)"                                                           = 7.4
    "Doctor Who (Bally 1992)"                                                          = 7.9
    "Dogies (Bally 1968)"                                                              = 7.7
    "Dolly Parton (Bally 1979)"                                                        = 6.8
    "Domino (Gottlieb 1968)"                                                           = 7.7
    "Doodle Bug (Williams 1971)"                                                       = 7.3
    "Double Barrel (Williams 1961)"                                                    = 7.1
    "Dr. Dude and His Excellent Ray (Bally 1990)"                                      = 7.8
    "Dracula (Stern 1979)"                                                             = 7
    "Dragon (Interflip 1977)"                                                          = 7.4
    "Dragon (SS) (Gottlieb 1978)"                                                      = 6
    "Drop-A-Card (Gottlieb 1971)"                                                      = 7.7
    "Dungeons & Dragons (Bally 1987)"                                                  = 7
    "Duotron (Gottlieb 1974)"                                                          = 6.6
    "Earthshaker (Williams 1989)"                                                      = 7.9
    "Egg Head (Gottlieb 1961)"                                                         = 7.1
    "Eight Ball (Bally 1977)"                                                          = 7.3
    "Eight Ball Champ (Bally 1985)"                                                    = 7.5
    "El Dorado (Gottlieb 1975)"                                                        = 7.8
    "El Dorado City of Gold (Gottlieb 1984)"                                           = 6.9
    "Elektra (Bally 1981)"                                                             = 7.4
    "Elvira and the Party Monsters - Nude Edition (Bally 1989)"                        = 7.9
    "Elvira and the Party Monsters (Bally 1989)"                                       = 7.9
    "Elvis (Stern 2004)"                                                               = 7.6
    "Embryon (Bally 1981)"                                                             = 7.9
    "Escape from the Lost World (Bally 1988)"                                          = 7.5
    "Evel Knievel (Bally 1977)"                                                        = 7.5
    "Eye Of The Tiger (Gottlieb 1978)"                                                 = 7.8
    "F-14 Tomcat (Williams 1987)"                                                      = 7.7
    "Faces (Sonic 1976)"                                                               = 7.2
    "Family Guy (Stern 2007)"                                                          = 7.8
    "Fan-Tas-Tic (Williams 1972)"                                                      = 7.7
    "Far Out (Gottlieb 1974)"                                                          = 7.3
    "Farfalla (Zaccaria 1983)"                                                         = 7.9
    "Fashion Show (Gottlieb 1962)"                                                     = 7.3
    "Fast Draw (Gottlieb 1975)"                                                        = 7.8
    "Fathom - LED Edition (Bally 1981)"                                                = 7.9
    "Fathom (Bally 1981)"                                                              = 7.9
    "Fire Queen (Gottlieb 1977)"                                                       = 7.7
    "Fire! (Williams 1987)"                                                            = 7.5
    "Fireball (Bally 1972)"                                                            = 7.8
    "Fireball Classic (Bally 1985)"                                                    = 7.4
    "Fireball II (Bally 1981)"                                                         = 7.8
    "Firecracker (Bally 1971)"                                                         = 7.4
    "Firepower (Williams 1980)"                                                        = 7.8
    "Firepower II (Williams 1983)"                                                     = 7.4
    "Firepower vs. A.I. (Williams 1980)"                                               = 7.8
    "Fish Tales (Williams 1992)"                                                       = 8.1
    "Flash (Williams 1979)"                                                            = 7.7
    "Flash Gordon (Bally 1981)"                                                        = 8
    "Flash, The (Original 2018)"                                                       = 7.7
    "Flicker (Bally 1975)"                                                             = 5.8
    "Flight 2000 (Stern 1980)"                                                         = 7.5
    "Flintstones, The - Cartoon Edition (Williams 1994)"                               = 7.9
    "Flintstones, The - The Cartoon VR Edition (Williams 1994)"                        = 7.9
    "Flintstones, The - VR Cartoon Edition (Williams 1994)"                            = 7.9
    "Flintstones, The - Yabba Dabba Re-Doo Edition (Williams 1994)"                    = 7.9
    "Flintstones, The (Williams 1994)"                                                 = 7.9
    "Flip a Card (Gottlieb 1970)"                                                      = 7.7
    "Flip Flop (Bally 1976)"                                                           = 6.8
    "Flipper Fair (Gottlieb 1961)"                                                     = 7.6
    "Flipper Football (Capcom 1996)"                                                   = 7
    "Flipper Pool (Gottlieb 1965)"                                                     = 8.3
    "Flying Carpet (Gottlieb 1972)"                                                    = 7.7
    "Flying Chariots (Gottlieb 1963)"                                                  = 6.7
    "Flying Turns (Midway 1964)"                                                       = 7.7
    "Force II (Gottlieb 1981)"                                                         = 6.8
    "Four Million B.C. (Bally 1971)"                                                   = 7.6
    "Four Seasons (Gottlieb 1968)"                                                     = 6.9
    "Frank Thomas'' Big Hurt (Gottlieb 1995)"                                          = 7.7
    "Freddy - A Nightmare on Elm Street (Gottlieb 1994)"                               = 7.5
    "Free Fall (Gottlieb 1974)"                                                        = 7.5
    "Freedom (EM) (Bally 1976)"                                                        = 7.7
    "Freefall (Stern 1981)"                                                            = 6.5
    "Frontier (Bally 1980)"                                                            = 7.4
    "Full (Recreativos Franco 1977)"                                                   = 7.7
    "Full House (Williams 1966)"                                                       = 7.5
    "Full Throttle (Original 2023)"                                                    = 8.2
    "Fun Land (Gottlieb 1968)"                                                         = 7.6
    "Fun Park (Gottlieb 1968)"                                                         = 8.2
    "Fun-Fest (Williams 1972)"                                                         = 7.2
    "Funhouse (Williams 1990)"                                                         = 8.1
    "Future Spa (Bally 1979)"                                                          = 7.5
    "Galaxy (Stern 1980)"                                                              = 7.4
    "Game of Thrones (Limited Edition) (Stern 2015)"                                   = 8.7
    "Gaucho (Gottlieb 1963)"                                                           = 7
    "Gay 90''s (Williams 1970)"                                                        = 7.7
    "Genesis (Gottlieb 1986)"                                                          = 7.4
    "Genie - Fuzzel Physics Edition (Gottlieb 1979)"                                   = 7.3
    "Genie (Gottlieb 1979)"                                                            = 7.3
    "Getaway - High Speed II, The (Williams 1992)"                                     = 8
    "Ghostbusters (Limited Edition) (Stern 2016)"                                      = 8.9
    "Gigi (Gottlieb 1963)"                                                             = 7.7
    "Gilligan''s Island (Bally 1991)"                                                  = 7.1
    "Gladiators (Gottlieb 1993)"                                                       = 7.3
    "Godzilla (Sega 1998)"                                                             = 7.1
    "Gold Ball (Bally 1983)"                                                           = 6.9
    "Gold Rush (Williams 1971)"                                                        = 7
    "Gold Strike (Gottlieb 1975)"                                                      = 7.8
    "Gold Wings (Gottlieb 1986)"                                                       = 6.9
    "Golden Arrow (Gottlieb 1977)"                                                     = 7.6
    "Goldeneye (Sega 1996)"                                                            = 7.7
    "Gorgar (Williams 1979)"                                                           = 7.5
    "Grand Lizard (Williams 1986)"                                                     = 7.5
    "Grand Prix (Stern 2005)"                                                          = 7.8
    "Grand Prix (Williams 1976)"                                                       = 7.5
    "Grand Slam (Gottlieb 1972)"                                                       = 7.7
    "Grand Tour (Bally 1964)"                                                          = 7.1
    "Gridiron (Gottlieb 1977)"                                                         = 8.5
    "Gulfstream (Williams 1973)"                                                       = 7.6
    "Guns N'' Roses (Data East 1994)"                                                  = 8
    "Hang Glider (Bally 1976)"                                                         = 7.7
    "Hardbody (Bally 1987)"                                                            = 6.6
    "Harlem Globetrotters on Tour (Bally 1979)"                                        = 7.5
    "Harley-Davidson (Bally 1991)"                                                     = 6.3
    "Harley-Davidson (Sega 1999)"                                                      = 6.7
    "Haunted House (Gottlieb 1982)"                                                    = 7.7
    "Hearts and Spades (Gottlieb 1969)"                                                = 7.6
    "Heat Wave (Williams 1964)"                                                        = 7.8
    "Heavy Metal Meltdown (Bally 1987)"                                                = 7.1
    "Hercules (Atari 1979)"                                                            = 5.1
    "Hi-Deal (Bally 1975)"                                                             = 7.4
    "Hi-Diver (Gottlieb 1959)"                                                         = 7.3
    "Hi-Lo Ace (Bally 1973)"                                                           = 7.6
    "Hi-Score (Gottlieb 1967)"                                                         = 7.3
    "Hi-Score Pool (Chicago Coin 1971)"                                                = 5.6
    "High Hand (Gottlieb 1973)"                                                        = 7.5
    "High Roller Casino (Stern 2001)"                                                  = 7.1
    "High Speed (Williams 1986)"                                                       = 8
    "Hit the Deck (Gottlieb 1978)"                                                     = 8.1
    "Hokus Pokus (Bally 1976)"                                                         = 7.5
    "Hollywood Heat (Gottlieb 1986)"                                                   = 7
    "Home Run (Gottlieb 1971)"                                                         = 7.4
    "Honey (Williams 1971)"                                                            = 7.3
    "Hook (Data East 1992)"                                                            = 7.5
    "Hoops (Gottlieb 1991)"                                                            = 7.3
    "Hot Hand (Stern 1979)"                                                            = 7.2
    "Hot Line (Williams 1966)"                                                         = 7.7
    "Hot Shot (Gottlieb 1973)"                                                         = 7.2
    "Hot Shots (Gottlieb 1989)"                                                        = 6.7
    "Hot Tip - Less Reflections Edition (Williams 1977)"                               = 7.5
    "Hot Tip (Williams 1977)"                                                          = 7.5
    "Hotdoggin'' (Bally 1980)"                                                         = 7.8
    "Humpty Dumpty (Gottlieb 1947)"                                                    = 7.2
    "Hurricane (Williams 1991)"                                                        = 7.5
    "Hyperball - Analog Joystick Edition (Williams 1981)"                              = 6.9
    "Hyperball - Analog Mouse Edition (Williams 1981)"                                 = 6.9
    "Hyperball (Williams 1981)"                                                        = 6.9
    "Ice Fever (Gottlieb 1985)"                                                        = 6.9
    "Impacto (Recreativos Franco 1975)"                                                = 7.5
    "Incredible Hulk, The (Gottlieb 1979)"                                             = 7.3
    "Independence Day (Sega 1996)"                                                     = 7.5
    "Indiana Jones - The Pinball Adventure (Williams 1993)"                            = 8.3
    "Indiana Jones (Stern 2008)"                                                       = 7.1
    "Indianapolis 500 (Bally 1995)"                                                    = 7.9
    "Iron Maiden (Stern 1982)"                                                         = 6.6
    "Iron Man (Stern 2010)"                                                            = 7.8
    "Jack in the Box (Gottlieb 1973)"                                                  = 7.6
    "Jack-Bot (Williams 1995)"                                                         = 7.6
    "Jackpot (Williams 1971)"                                                          = 7.7
    "Jacks Open (Gottlieb 1977)"                                                       = 7.8
    "Jacks to Open (Gottlieb 1984)"                                                    = 7
    "James Bond 007 (Gottlieb 1980)"                                                   = 6
    "James Cameron''s Avatar (Stern 2010)"                                             = 7.3
    "Jet Spin (Gottlieb 1977)"                                                         = 7.8
    "Jive Time (Williams 1970)"                                                        = 6.5
    "Johnny Mnemonic (Williams 1995)"                                                  = 7.8
    "Joker Poker (EM) (Gottlieb 1978)"                                                 = 7.8
    "Joker Poker (SS) (Gottlieb 1978)"                                                 = 8
    "Jokerz! (Williams 1988)"                                                          = 7.6
    "Jolly Park (Spinball S.A.L. 1996)"                                                = 7.5
    "Jolly Roger (Williams 1967)"                                                      = 7.4
    "Joust (Bally 1969)"                                                               = 7.3
    "JP''s Addams Family (Bally 1992)"                                                 = 8.3
    "JP''s Captain Fantastic (Bally 1976)"                                             = 7.7
    "JP''s Cyclone (Original 2022)"                                                    = 8
    "JP''s Grand Prix (Stern 2005)"                                                    = 7.8
    "JP''s Indiana Jones (Stern 2008)"                                                 = 7.1
    "JP''s Metallica Pro (Stern 2013)"                                                 = 7.9
    "JP''s Nascar Race (Original 2015)"                                                = 6.9
    "JP''s Seawitch (Stern 1980)"                                                      = 7.4
    "JP''s Spider-Man (Original 2018)"                                                 = 8.1
    "JP''s Star Trek (Enterprise Limited Edition) (Original 2020)"                     = 8.9
    "JP''s Street Fighter II (Original 2016)"                                          = 7.2
    "JP''s Terminator 2 (Original 2020)"                                               = 8
    "JP''s Terminator 3 (Stern 2003)"                                                  = 7.5
    "JP''s The Avengers (Original 2019)"                                               = 6.4
    "JP''s The Lord of the Rings (Stern 2003)"                                         = 8.1
    "JP''s The Lost World Jurassic Park (Original 2020)"                               = 7.2
    "JP''s The Walking Dead (Original 2021)"                                           = 8
    "JP''s Transformers (Original 2018)"                                               = 7.7
    "Jubilee (Williams 1973)"                                                          = 4.9
    "Judge Dredd (Bally 1993)"                                                         = 8
    "Jumping Jack (Gottlieb 1973)"                                                     = 7.7
    "Jungle (Gottlieb 1972)"                                                           = 6.7
    "Jungle King (Gottlieb 1973)"                                                      = 7.4
    "Jungle Lord (Williams 1981)"                                                      = 7.7
    "Jungle Princess (Gottlieb 1977)"                                                  = 7.7
    "Jungle Queen (Gottlieb 1977)"                                                     = 7.8
    "Junk Yard (Williams 1996)"                                                        = 8
    "Jurassic Park (Data East 1993)"                                                   = 8
    "Kick Off (Bally 1977)"                                                            = 7.5
    "King Kool (Gottlieb 1972)"                                                        = 7.6
    "King of Diamonds (Gottlieb 1967)"                                                 = 7.8
    "King Pin (Gottlieb 1973)"                                                         = 7.8
    "King Pin (Williams 1962)"                                                         = 7.5
    "King Rock (Gottlieb 1972)"                                                        = 6.9
    "King Tut (Bally 1969)"                                                            = 5.3
    "Kingpin (Capcom 1996)"                                                            = 6.8
    "Kings & Queens (Gottlieb 1965)"                                                   = 7.8
    "Kings of Steel (Bally 1984)"                                                      = 7.4
    "KISS - PuP-Pack Edition (Bally 1979)"                                             = 7
    "KISS (Bally 1979)"                                                                = 7
    "Klondike (Williams 1971)"                                                         = 7.8
    "Knock Out (Gottlieb 1950)"                                                        = 7.2
    "Lady Luck (Bally 1986)"                                                           = 6.4
    "Lady Luck (Recel 1976)"                                                           = 7.3
    "Laser Ball (Williams 1979)"                                                       = 7.2
    "Laser Cue (Williams 1984)"                                                        = 7.4
    "Last Action Hero (Data East 1993)"                                                = 7.9
    "Lawman (Gottlieb 1971)"                                                           = 7.8
    "Lectronamo (Stern 1978)"                                                          = 7.2
    "Lethal Weapon 3 (Data East 1992)"                                                 = 7.6
    "Liberty Bell (Williams 1977)"                                                     = 7.1
    "Lightning (Stern 1981)"                                                           = 7.5
    "Lightning Ball (Gottlieb 1959)"                                                   = 8.5
    "Lights...Camera...Action! (Gottlieb 1989)"                                        = 7.2
    "Line Drive (Williams 1972)"                                                       = 7.7
    "Little Chief (Williams 1975)"                                                     = 7.8
    "Little Joe (Bally 1972)"                                                          = 7.7
    "Locomotion (Zaccaria 1981)"                                                       = 8.1
    "Lord of the Rings, The - Valinor Edition (Stern 2003)"                            = 8.1
    "Lord of the Rings, The (Stern 2003)"                                              = 8.1
    "Lost in Space (Sega 1998)"                                                        = 6.7
    "Lost World (Bally 1978)"                                                          = 7
    "Lost World Jurassic Park, The (Sega 1997)"                                        = 7.2
    "Lucky Ace (Williams 1974)"                                                        = 7.4
    "Lucky Hand (Gottlieb 1977)"                                                       = 7.7
    "Lucky Seven (Williams 1978)"                                                      = 6.9
    "Machine - Bride of Pin-bot, The (Williams 1991)"                                  = 8
    "Magic (Stern 1979)"                                                               = 7.4
    "Magic City (Williams 1967)"                                                       = 7.6
    "Magic Clock (Williams 1960)"                                                      = 8.5
    "Magnotron (Gottlieb 1974)"                                                        = 6.2
    "Mariner (Bally 1971)"                                                             = 7
    "Mario Andretti (Gottlieb 1995)"                                                   = 6.9
    "Mars God of War (Gottlieb 1981)"                                                  = 7.3
    "Mars Trek (Sonic 1977)"                                                           = 7.5
    "Mary Shelley''s Frankenstein - B&W Edition (Sega 1995)"                           = 7.9
    "Mary Shelley''s Frankenstein (Sega 1995)"                                         = 7.9
    "Masquerade (Gottlieb 1966)"                                                       = 7.5
    "Mata Hari (Bally 1978)"                                                           = 7.8
    "Maverick (Data East 1994)"                                                        = 7.5
    "Medieval Madness - B&W Edition (Williams 1997)"                                   = 8.3
    "Medieval Madness - Redux Edition (Williams 1997)"                                 = 8.3
    "Medieval Madness - Remake Edition (Williams 1997)"                                = 8.3
    "Medieval Madness (Williams 1997)"                                                 = 8.3
    "Medusa (Bally 1981)"                                                              = 7.5
    "Melody (Gottlieb 1967)"                                                           = 7.7
    "Metallica - Master of Puppets (Original 2020)"                                    = 7.4
    "Metallica (Premium Monsters) - Christmas Edition (Stern 2013)"                    = 7.4
    "Metallica (Premium Monsters) (Stern 2013)"                                        = 7.4
    "Meteor (Stern 1979)"                                                              = 7.6
    "Mibs (Gottlieb 1969)"                                                             = 7.1
    "Middle Earth (Atari 1978)"                                                        = 6.4
    "Millionaire (Williams 1987)"                                                      = 7
    "Mini Pool (Gottlieb 1969)"                                                        = 7.7
    "Miss-O (Williams 1969)"                                                           = 6.8
    "Monaco (Segasa 1977)"                                                             = 7.8
    "Monday Night Football (Data East 1989)"                                           = 7.3
    "Monopoly (Stern 2001)"                                                            = 7.3
    "Monster Bash (Williams 1998)"                                                     = 8.2
    "Monte Carlo (Bally 1973)"                                                         = 7.7
    "Monte Carlo (Gottlieb 1987)"                                                      = 7
    "Moon Walking Dead, The (Original 2017)"                                           = 7.4
    "Motordome (Bally 1986)"                                                           = 6.6
    "Moulin Rouge (Williams 1965)"                                                     = 7.6
    "Mousin'' Around! (Bally 1989)"                                                    = 7.8
    "Mr. & Mrs. Pac-Man Pinball (Bally 1982)"                                          = 7
    "Mustang (Gottlieb 1977)"                                                          = 7.2
    "Mystery Castle (Alvin G. 1993)"                                                   = 7.2
    "Mystic (Bally 1980)"                                                              = 6.8
    "Nags (Williams 1960)"                                                             = 7.5
    "NASCAR - Dale Jr. (Stern 2005)"                                                   = 6.9
    "NASCAR - Grand Prix (Stern 2005)"                                                 = 6.9
    "NASCAR (Stern 2005)"                                                              = 6.9
    "NBA (Stern 2009)"                                                                 = 7.3
    "NBA Fastbreak (Bally 1997)"                                                       = 7.7
    "Neptune (Gottlieb 1978)"                                                          = 7.7
    "Night Moves (International Concepts 1989)"                                        = 7.3
    "Night Rider (Bally 1977)"                                                         = 7.7
    "Nine Ball (Stern 1980)"                                                           = 7.2
    "Nip-It (Bally 1973)"                                                              = 7.6
    "Nitro Ground Shaker (Bally 1980)"                                                 = 7.8
    "No Fear - Dangerous Sports (Williams 1995)"                                       = 7.7
    "No Good Gofers (Williams 1997)"                                                   = 8
    "North Star (Gottlieb 1964)"                                                       = 7.7
    "Now (Gottlieb 1971)"                                                              = 5.9
    "Nugent (Stern 1978)"                                                              = 6.4
    "Old Chicago (Bally 1976)"                                                         = 7.5
    "Olympics (Gottlieb 1962)"                                                         = 6.9
    "On Beam (Bally 1969)"                                                             = 7.3
    "Op-Pop-Pop (Bally 1969)"                                                          = 7
    "Operation Thunder (Gottlieb 1992)"                                                = 7.7
    "Orbit (Gottlieb 1971)"                                                            = 6.2
    "Orbitor 1 (Stern 1982)"                                                           = 5.9
    "Out of Sight (Gottlieb 1974)"                                                     = 7.7
    "Outer Space (Gottlieb 1972)"                                                      = 7.8
    "OXO (Williams 1973)"                                                              = 8
    "Paddock (Williams 1969)"                                                          = 7.4
    "Palace Guard (Gottlieb 1968)"                                                     = 7.5
    "Panthera (Gottlieb 1980)"                                                         = 6.8
    "Paradise (Gottlieb 1965)"                                                         = 7.6
    "Paragon (Bally 1979)"                                                             = 7.9
    "Party Animal (Bally 1987)"                                                        = 7
    "Party Zone, The (Bally 1991)"                                                     = 7.7
    "Pat Hand (Williams 1975)"                                                         = 7
    "Paul Bunyan (Gottlieb 1968)"                                                      = 7.4
    "Phantom of the Opera (Data East 1990)"                                            = 7.2
    "Pharaoh - Dead Rise (Original 2019)"                                              = 7.2
    "Pharaoh (Williams 1981)"                                                          = 7.2
    "Phoenix (Williams 1978)"                                                          = 7.2
    "PIN-BOT (Williams 1986)"                                                          = 8
    "Pin-Up (Gottlieb 1975)"                                                           = 7.6
    "Pinball (SS) (Stern 1977)"                                                        = 7.5
    "Pinball Lizard (Game Plan 1980)"                                                  = 7.1
    "Pinball Magic (Capcom 1995)"                                                      = 8
    "Pinball Pool (Gottlieb 1979)"                                                     = 7.4
    "Pink Panther (Gottlieb 1981)"                                                     = 7
    "Pioneer (Gottlieb 1976)"                                                          = 7.3
    "Pirates of the Caribbean (Stern 2006)"                                            = 7.6
    "Pistol Poker (Alvin G. 1993)"                                                     = 6.9
    "Pit Stop (Williams 1968)"                                                         = 6.8
    "Playball (Gottlieb 1971)"                                                         = 6.9
    "Playboy - Definitive Edition (Bally 1978)"                                        = 7.6
    "Playboy (Bally 1978)"                                                             = 7.6
    "Playboy 35th Anniversary (Data East 1989)"                                        = 6.9
    "Pokerino (Williams 1978)"                                                         = 5.8
    "Police Force (Williams 1989)"                                                     = 7.6
    "Pool Sharks (Bally 1990)"                                                         = 7.1
    "Pop-A-Card (Gottlieb 1972)"                                                       = 7.7
    "Popeye Saves the Earth (Bally 1994)"                                              = 7.4
    "Post Time (Williams 1969)"                                                        = 7.7
    "Pro Pool (Gottlieb 1973)"                                                         = 7.7
    "Pro-Football (Gottlieb 1973)"                                                     = 7.6
    "Prospector (Sonic 1977)"                                                          = 7.4
    "Queen of Hearts (Gottlieb 1952)"                                                  = 7.8
    "Quick Draw (Gottlieb 1975)"                                                       = 7.7
    "Quicksilver (Stern 1980)"                                                         = 7.4
    "Rack ''Em Up! (Gottlieb 1983)"                                                    = 7.2
    "Rack-A-Ball (Gottlieb 1962)"                                                      = 6.7
    "Radical! (Bally 1990)"                                                            = 7.8
    "Radical! (prototype) (Bally 1990)"                                                = 7.8
    "Rainbow (Gottlieb 1956)"                                                          = 8.6
    "Rambo (Original 2019)"                                                            = 5.9
    "Rancho (Williams 1976)"                                                           = 7.6
    "Raven (Gottlieb 1986)"                                                            = 5.9
    "Red & Ted''s Road Show (Williams 1994)"                                           = 8
    "Red Baron (Chicago Coin 1975)"                                                    = 4.4
    "Rescue 911 (Gottlieb 1994)"                                                       = 7.6
    "Ripley''s Believe it or Not! (Stern 2004)"                                        = 8
    "Riverboat Gambler (Williams 1990)"                                                = 7.3
    "Ro Go (Bally 1974)"                                                               = 5.2
    "Road Kings (Williams 1986)"                                                       = 7.5
    "Road Race (Gottlieb 1969)"                                                        = 7
    "Robo-War (Gottlieb 1988)"                                                         = 7
    "Robocop (Data East 1989)"                                                         = 7.3
    "Robot (Zaccaria 1985)"                                                            = 8.4
    "Rock (Gottlieb 1985)"                                                             = 6.4
    "Rocket III (Bally 1967)"                                                          = 7.5
    "RockMakers (Bally 1968)"                                                          = 6.9
    "Rocky (Gottlieb 1982)"                                                            = 7
    "Roller Coaster (Gottlieb 1971)"                                                   = 7.4
    "Roller Disco (Gottlieb 1980)"                                                     = 7.3
    "RollerCoaster Tycoon (Stern 2002)"                                                = 7.1
    "Rollergames (Williams 1990)"                                                      = 7.5
    "Rolling Stones - B&W Edition (Bally 1980)"                                        = 6.8
    "Rolling Stones (Bally 1980)"                                                      = 6.8
    "Rolling Stones, The (Stern 2011)"                                                 = 6.8
    "Royal Flush (Gottlieb 1976)"                                                      = 7.8
    "Royal Guard (Gottlieb 1968)"                                                      = 7.7
    "Safe Cracker (Bally 1996)"                                                        = 7.9
    "Satin Doll (Williams 1975)"                                                       = 5.9
    "Scared Stiff (Bally 1996)"                                                        = 8.3
    "Scorpion (Williams 1980)"                                                         = 7.3
    "Scuba (Gottlieb 1970)"                                                            = 7.8
    "Sea Ray (Bally 1971)"                                                             = 7.2
    "Seawitch (Stern 1980)"                                                            = 7.4
    "Secret Service (Data East 1988)"                                                  = 7.5
    "Shadow, The (Bally 1994)"                                                         = 8.1
    "Shangri-La (Williams 1967)"                                                       = 7.6
    "Shaq Attaq (Gottlieb 1995)"                                                       = 7.3
    "Sharkey''s Shootout (Stern 2000)"                                                 = 7.1
    "Sharpshooter (Game Plan 1979)"                                                    = 7.4
    "Sheriff (Gottlieb 1971)"                                                          = 7.6
    "Ship Ahoy (Gottlieb 1976)"                                                        = 7.6
    "Ship-Mates (Gottlieb 1964)"                                                       = 7.1
    "Shrek (Stern 2008)"                                                               = 7.6
    "Silver Slugger (Gottlieb 1990)"                                                   = 7.4
    "Silverball Mania (Bally 1980)"                                                    = 7.4
    "Simpsons Pinball Party, The (Stern 2003)"                                         = 8
    "Simpsons Treehouse of Horror, The - Starlion Edition (Original 2020)"             = 8
    "Simpsons Treehouse of Horror, The (Original 2020)"                                = 8
    "Simpsons, The (Data East 1990)"                                                   = 7.5
    "Sinbad (Gottlieb 1978)"                                                           = 7.6
    "Sing Along (Gottlieb 1967)"                                                       = 7.8
    "Sittin'' Pretty (Gottlieb 1958)"                                                  = 7.8
    "Six Million Dollar Man, The (Bally 1978)"                                         = 7.3
    "Skateball (Bally 1980)"                                                           = 7.5
    "Skipper (Gottlieb 1969)"                                                          = 6.7
    "Sky Jump (Gottlieb 1974)"                                                         = 7.5
    "Sky Kings (Bally 1974)"                                                           = 7.1
    "Sky-Line (Gottlieb 1965)"                                                         = 7.7
    "Skylab (Williams 1974)"                                                           = 6.8
    "Skyrocket (Bally 1971)"                                                           = 7.6
    "Slick Chick (Gottlieb 1963)"                                                      = 7.8
    "Smart Set (Williams 1969)"                                                        = 7.1
    "Snow Derby (Gottlieb 1970)"                                                       = 7.6
    "Snow Queen (Gottlieb 1970)"                                                       = 7.2
    "Soccer (Gottlieb 1975)"                                                           = 7.4
    "Soccer (Williams 1964)"                                                           = 7.2
    "Solar City (Gottlieb 1977)"                                                       = 7.5
    "Solar Fire (Williams 1981)"                                                       = 7.4
    "Solar Ride (Gottlieb 1979)"                                                       = 7.5
    "Solids N Stripes (Williams 1971)"                                                 = 6.3
    "Sopranos, The (Stern 2005)"                                                       = 7.4
    "Sorcerer (Williams 1985)"                                                         = 7.8
    "Sound Stage (Chicago Coin 1976)"                                                  = 5.8
    "South Park (Sega 1999)"                                                           = 7
    "Space Invaders (Bally 1980)"                                                      = 7.7
    "Space Mission (Williams 1976)"                                                    = 7.8
    "Space Odyssey (Williams 1976)"                                                    = 7.5
    "Space Riders (Atari 1978)"                                                        = 7.3
    "Space Shuttle (Williams 1984)"                                                    = 7.7
    "Space Station (Williams 1987)"                                                    = 7.7
    "Space Time (Bally 1972)"                                                          = 7.4
    "Spanish Eyes (Williams 1972)"                                                     = 7.7
    "Speakeasy (Bally 1982)"                                                           = 7.2
    "Speakeasy (Playmatic 1977)"                                                       = 7.1
    "Special Force (Bally 1986)"                                                       = 6.6
    "Spectrum (Bally 1982)"                                                            = 7
    "Spider-Man - Classic Edition (Stern 2007)"                                        = 8.1
    "Spider-Man (Black Suited) (Stern 2007)"                                           = 7.6
    "Spider-Man (Stern 2007)"                                                          = 8.1
    "Spider-Man (Vault Edition) - Classic Edition (Stern 2016)"                        = 8.5
    "Spider-Man (Vault Edition) (Stern 2016)"                                          = 8.5
    "Spin Out (Gottlieb 1975)"                                                         = 7.4
    "Spin Wheel (Gottlieb 1968)"                                                       = 6.9
    "Spin-A-Card (Gottlieb 1969)"                                                      = 7.6
    "Spirit (Gottlieb 1982)"                                                           = 7.3
    "Spirit of 76 (Gottlieb 1975)"                                                     = 7.6
    "Split Second (Stern 1981)"                                                        = 7.1
    "Spot a Card (Gottlieb 1960)"                                                      = 8.3
    "Spring Break (Gottlieb 1987)"                                                     = 6.5
    "Spy Hunter (Bally 1984)"                                                          = 7.3
    "Star Action (Williams 1973)"                                                      = 7.6
    "Star Gazer (Stern 1980)"                                                          = 7.4
    "Star Light (Williams 1984)"                                                       = 6.9
    "Star Pool (Williams 1974)"                                                        = 6.9
    "Star Race (Gottlieb 1980)"                                                        = 7.2
    "Star Trek - Mirror Universe Edition (Bally 1979)"                                 = 7.1
    "Star Trek - The Next Generation (Williams 1993)"                                  = 8.3
    "Star Trek (Bally 1979)"                                                           = 7.1
    "Star Trek (Data East 1991)"                                                       = 7.4
    "Star Trek (Enterprise Limited Edition) (Stern 2013)"                              = 8
    "Star Wars - The Empire Strikes Back (Hankin 1980)"                                = 7
    "Star Wars (Data East 1992)"                                                       = 8
    "Star Wars Trilogy Special Edition (Sega 1997)"                                    = 7.2
    "Star-Jet (Bally 1963)"                                                            = 7.6
    "Stardust (Williams 1971)"                                                         = 7.3
    "Stargate (Gottlieb 1995)"                                                         = 8
    "Stars (Stern 1978)"                                                               = 7.4
    "Starship Troopers - VPN Edition (Sega 1997)"                                      = 7.8
    "Starship Troopers (Sega 1997)"                                                    = 7.8
    "Stellar Wars (Williams 1979)"                                                     = 7.5
    "Stingray (Stern 1977)"                                                            = 7.3
    "Straight Flush (Williams 1970)"                                                   = 6.8
    "Strange Science (Bally 1986)"                                                     = 7.6
    "Strange World (Gottlieb 1978)"                                                    = 7.7
    "Strato-Flite (Williams 1974)"                                                     = 7.7
    "Street Fighter II (Gottlieb 1993)"                                                = 7.2
    "Striker (Gottlieb 1982)"                                                          = 7.5
    "Striker Xtreme (Stern 2000)"                                                      = 6.9
    "Strikes and Spares (Bally 1978)"                                                  = 7.7
    "Strikes N'' Spares (Gottlieb 1995)"                                               = 6.8
    "Strip Joker Poker (Gottlieb 1978)"                                                = 8
    "Student Prince (Williams 1968)"                                                   = 7.9
    "Super Mario Bros. (Gottlieb 1992)"                                                = 7.4
    "Super Mario Bros. Mushroom World (Gottlieb 1992)"                                 = 7.3
    "Super Orbit (Gottlieb 1983)"                                                      = 5.6
    "Super Score (Gottlieb 1967)"                                                      = 7.7
    "Super Soccer (Gottlieb 1975)"                                                     = 7.3
    "Super Spin (Gottlieb 1977)"                                                       = 7.8
    "Super Star (Williams 1972)"                                                       = 7.4
    "Super Straight (Sonic 1977)"                                                      = 7.3
    "Super-Flite (Williams 1974)"                                                      = 7.1
    "Superman (Atari 1979)"                                                            = 7.3
    "Supersonic (Bally 1979)"                                                          = 7.2
    "Sure Shot (Gottlieb 1976)"                                                        = 7.8
    "Surf ''n Safari (Gottlieb 1991)"                                                  = 7.2
    "Surf Champ (Gottlieb 1976)"                                                       = 7.7
    "Surf Side (Gottlieb 1967)"                                                        = 7.4
    "Surfer (Gottlieb 1976)"                                                           = 7.8
    "Sweet Hearts (Gottlieb 1963)"                                                     = 7.7
    "Swing-Along (Gottlieb 1963)"                                                      = 7.3
    "Swinger (Williams 1972)"                                                          = 7.4
    "Swords of Fury (Williams 1988)"                                                   = 7.9
    "T.K.O. (Gottlieb 1979)"                                                           = 6.5
    "Tag-Team Pinball (Gottlieb 1985)"                                                 = 7.8
    "Tales from the Crypt (Data East 1993)"                                            = 7.9
    "Tales of the Arabian Nights (Williams 1996)"                                      = 8.2
    "Target Alpha (Gottlieb 1976)"                                                     = 7.7
    "Target Pool (Gottlieb 1969)"                                                      = 7.7
    "Taxi - Lola Edition (Williams 1988)"                                              = 8
    "Taxi (Williams 1988)"                                                             = 8
    "Teacher''s Pet (Williams 1965)"                                                   = 7.7
    "Team One (Gottlieb 1977)"                                                         = 7.6
    "Tee''d Off (Gottlieb 1993)"                                                       = 7.5
    "Teenage Mutant Ninja Turtles - PuP-Pack Edition (Data East 1991)"                 = 6.8
    "Teenage Mutant Ninja Turtles (Data East 1991)"                                    = 6.8
    "Terminator 2 - Judgment Day - Chrome Edition (Williams 1991)"                     = 8
    "Terminator 2 - Judgment Day (Williams 1991)"                                      = 8
    "Terminator 3 - Rise of the Machines (Stern 2003)"                                 = 7.5
    "Theatre of Magic (Bally 1995)"                                                    = 8.3
    "Time Fantasy (Williams 1983)"                                                     = 7
    "Time Line (Gottlieb 1980)"                                                        = 7.5
    "Time Machine (Data East 1988)"                                                    = 7.9
    "Time Machine (Zaccaria 1983)"                                                     = 6.4
    "Time Warp (Williams 1979)"                                                        = 7.5
    "Title Fight (Gottlieb 1990)"                                                      = 6.9
    "Toledo (Williams 1975)"                                                           = 6.7
    "Top Card (Gottlieb 1974)"                                                         = 7.7
    "Top Score (Gottlieb 1975)"                                                        = 7.8
    "Torch (Gottlieb 1980)"                                                            = 6.9
    "Torpedo Alley (Data East 1988)"                                                   = 7.3
    "Total Nuclear Annihilation - Welcome to the Future Edition (Spooky Pinball 2017)" = 7.9
    "Total Nuclear Annihilation (Spooky Pinball 2017)"                                 = 7.9
    "Totem (Gottlieb 1979)"                                                            = 7.3
    "Touchdown (Gottlieb 1984)"                                                        = 6.8
    "Touchdown (Williams 1967)"                                                        = 7.8
    "Trade Winds (Williams 1962)"                                                      = 7.8
    "Transformers (Pro) (Stern 2011)"                                                  = 7.7
    "Transporter the Rescue (Bally 1989)"                                              = 7.4
    "Travel Time (Williams 1972)"                                                      = 7.6
    "Tri Zone (Williams 1979)"                                                         = 6.9
    "Trident (Stern 1979)"                                                             = 7
    "Triple Action (Williams 1973)"                                                    = 7.6
    "Triple Strike (Williams 1975)"                                                    = 7.7
    "TRON Classic - PuP-Pack Edition (Original 2018)"                                  = 6.8
    "TRON Classic (Original 2018)"                                                     = 6.8
    "Truck Stop (Bally 1988)"                                                          = 7.5
    "Twilight Zone - B&W Edition (Bally 1993)"                                         = 8.4
    "Twilight Zone (Bally 1993)"                                                       = 8.4
    "Twinky (Chicago Coin 1967)"                                                       = 7.1
    "Twister (Sega 1996)"                                                              = 7.1
    "TX-Sector (Gottlieb 1988)"                                                        = 7.3
    "Universe (Gottlieb 1959)"                                                         = 7.5
    "Vampire (Bally 1971)"                                                             = 6
    "Vector (Bally 1982)"                                                              = 7.4
    "Vegas (Gottlieb 1990)"                                                            = 7.6
    "Victory (Gottlieb 1987)"                                                          = 7
    "Viking (Bally 1980)"                                                              = 7.5
    "Viper Night Drivin'' (Sega 1998)"                                                 = 6.8
    "Volcano (Gottlieb 1981)"                                                          = 7.5
    "Volley (Gottlieb 1976)"                                                           = 7.7
    "Voltan Escapes Cosmic Doom (Bally 1979)"                                          = 6.9
    "Vulcan (Gottlieb 1977)"                                                           = 7.7
    "Walking Dead (Limited Edition), The (Stern 2014)"                                 = 7.4
    "Walking Dead (Pro), The (Stern 2014)"                                             = 8
    "Waterworld (Gottlieb 1995)"                                                       = 6.9
    "Wheel of Fortune (Stern 2007)"                                                    = 7.4
    "Whirlwind (Williams 1990)"                                                        = 8
    "White Water (Williams 1993)"                                                      = 8.2
    "WHO dunnit (Bally 1995)"                                                          = 7.9
    "Who''s Tommy Pinball Wizard, The (Data East 1994)"                                = 8
    "Wiggler, The (Bally 1967)"                                                        = 7.6
    "Wild Card (Williams 1977)"                                                        = 7.6
    "Wild Fyre (Stern 1978)"                                                           = 7.6
    "Wild Life (Gottlieb 1972)"                                                        = 6.9
    "Wild Wild West (Gottlieb 1969)"                                                   = 7.7
    "Winner (Williams 1971)"                                                           = 6.4
    "Wipe Out (Gottlieb 1993)"                                                         = 7.5
    "Wizard! (Bally 1975)"                                                             = 7.7
    "World Challenge Soccer (Gottlieb 1994)"                                           = 7
    "World Cup (Williams 1978)"                                                        = 6.4
    "World Cup Soccer (Bally 1994)"                                                    = 8
    "World Poker Tour (Stern 2006)"                                                    = 7.2
    "World Series (Gottlieb 1972)"                                                     = 7.6
    "WWF Royal Rumble (Data East 1994)"                                                = 7.9
    "X Files, The (Sega 1997)"                                                         = 6.7
    "X-Men Wolverine LE (Stern 2012)"                                                  = 8
    "X''s & O''s (Bally 1984)"                                                         = 6.8
    "Xenon (Bally 1980)"                                                               = 7.8
    "Zip-A-Doo (Bally 1970)"                                                           = 7.3
    "Zodiac (Williams 1971)"                                                           = 6.4
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

                    $details = ''
                    $rating = [double]0.0
                    if ($script:ipdbRatings.ContainsKey($pupkey)) {
                        $rating = $script:ipdbRatings[$pupkey]
                        $details += "$rating/10; "
                    }

                    if ($script:puplookup.ContainsKey($pupkey)) {
                        $numPlayers = $script:puplookup[$pupkey].Players
                        if ($numPlayers -ne 0) {
                            $details += " $numPlayers player(s); "
                        }

                        $details += ' {0}; {1}' -f `
                            $script:puplookup[$pupkey].Type, `
                            $script:puplookup[$pupkey].Theme
                    }
                    else {
                        $details = $listView.SelectedItems.SubItems[$script:colDetails].Text
                    }

                    $tableMeta = @{
                        Name    = $pupkey
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
                    if ($IPDBNum -ne 0) {
                        Start-Process -FilePath "https://www.ipdb.org/machine.cgi?id=$IPDBNum"
                    }
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
