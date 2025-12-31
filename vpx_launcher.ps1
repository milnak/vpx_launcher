[CmdletBinding()]
Param(
    # Location to the VPinball EXE
    [string]$PinballExe = (Resolve-Path 'VPinballX64.exe'),
    # Folder containing VPX tables
    [string]$TablePath = (Resolve-Path 'Tables'),
    # Zero-based display number to use. Find numbers in Settings > System > Display
    [int]$Display = -1
)

$script:launcherVersion = '1.7.4'

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

# =============================================================================
# Global Variables

$script:metadataCache = @{}
$script:launchCount = @{}

# =============================================================================
# Table metadata
# Exported from https://virtualpinballspreadsheet.github.io/export as CSV
# and converted using (Note: Not currently using Manufact,GameYear, GameType)
# Import-Csv .\puplookup.csv | Where-Object WebLinkURL -ne '' | Select-Object -Unique GameName,WebLinkURL | Where-Object WebLinkURL -ne '' `
# | ForEach-Object { '''{0}'' = ''{1}''' -f ($_.GameName -replace '''', ''''''), $_.WebLinkURL } | Set-Clipboard

$script:puplookup = @{
    '!WOW! (Mills Novelty Company 1932)'                                               = 'https://www.ipdb.org/machine.cgi?id=2819'
    '''300'' (Gottlieb 1975)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2539'
    '1-2-3 (Automaticos 1973)'                                                         = 'https://www.ipdb.org/machine.cgi?id=5247'
    '2 in 1 (Bally 1964)'                                                              = 'http://www.ipdb.org/machine.cgi?id=2698'
    '2001 (Gottlieb 1971)'                                                             = 'http://www.ipdb.org/machine.cgi?id=2697'
    '24 (Stern 2009)'                                                                  = 'http://www.ipdb.org/machine.cgi?id=5419'
    '250 cc (Inder 1992)'                                                              = 'http://www.ipdb.org/machine.cgi?id=4089'
    '3-In-Line (Bally 1963)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2549'
    '301 Bullseye (Grand Products 1986)'                                               = 'https://www.ipdb.org/machine.cgi?id=403'
    '4 Aces (Williams 1970)'                                                           = 'https://www.ipdb.org/machine.cgi?id=928'
    '4 Queens (Bally 1970)'                                                            = 'http://www.ipdb.org/machine.cgi?id=936'
    '4 Roses (Williams 1962)'                                                          = 'https://www.ipdb.org/machine.cgi?id=938'
    '4 Square (Gottlieb 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=940'
    '4X4 (Atari 1983)'                                                                 = 'http://www.ipdb.org/machine.cgi?id=3111'
    '8 Ball (Williams 1966)'                                                           = 'https://www.ipdb.org/machine.cgi?id=764'
    'A-Go-Go (Williams 1966)'                                                          = 'https://www.ipdb.org/machine.cgi?id=27'
    'AC/DC (LUCI Premium) (Stern 2013)'                                                = 'https://www.ipdb.org/machine.cgi?id=6060'
    'AC/DC (LUCI Vault Edition) (Stern 2018)'                                          = 'https://www.ipdb.org/machine.cgi?id=6502'
    'AC/DC (Let There Be Rock Limited Edition) (Stern 2012)'                           = 'https://www.ipdb.org/machine.cgi?id=5776'
    'AC/DC (Premium) (Stern 2012)'                                                     = 'https://www.ipdb.org/machine.cgi?id=5775'
    'AC/DC (Pro Vault Edition) (Stern 2017)'                                           = 'https://www.ipdb.org/machine.cgi?id=6439'
    'AC/DC (Pro) (Stern 2012)'                                                         = 'https://www.ipdb.org/machine.cgi?id=5767'
    'AC/DC Back In Black (Limited Edition) (Stern 2012)'                               = 'https://www.ipdb.org/machine.cgi?id=5777'
    'Aaron Spelling (Data East 1992)'                                                  = 'http://www.ipdb.org/machine.cgi?id=4339'
    'Abra Ca Dabra (Gottlieb 1975)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2'
    'Ace High (Gottlieb 1957)'                                                         = 'https://www.ipdb.org/machine.cgi?id=7'
    'Aces & Kings (Williams 1970)'                                                     = 'https://www.ipdb.org/machine.cgi?id=11'
    'Aces High (Bally 1965)'                                                           = 'http://www.ipdb.org/machine.cgi?id=9'
    'Adventure (Sega 1979)'                                                            = 'https://www.ipdb.org/machine.cgi?id=5544'
    'Adventures of Rocky and Bullwinkle and Friends (Data East 1993)'                  = 'http://www.ipdb.org/machine.cgi?id=23'
    'Aerobatics (Zaccaria 1977)'                                                       = 'https://www.ipdb.org/machine.cgi?id=24'
    'Aerosmith (Pro) (Stern 2017)'                                                     = 'https://www.ipdb.org/machine.cgi?id=6370'
    'Agents 777 (Game Plan 1984)'                                                      = 'http://www.ipdb.org/machine.cgi?id=26'
    'Air Aces (Bally 1975)'                                                            = 'https://www.ipdb.org/machine.cgi?id=28'
    'Airborne (J. Esteban 1979)'                                                       = 'https://www.ipdb.org/machine.cgi?id=5133'
    'Airborne (Capcom 1996)'                                                           = 'http://www.ipdb.org/machine.cgi?id=3783'
    'Airborne Avenger (Atari 1977)'                                                    = 'http://www.ipdb.org/machine.cgi?id=33'
    'Airport (Gottlieb 1969)'                                                          = 'http://www.ipdb.org/machine.cgi?id=35'
    'Al Capone (LTD do Brasil 1984)'                                                   = 'https://www.ipdb.org/machine.cgi?id=5176'
    'Al''s Garage Band Goes on a World Tour (Alvin G. 1992)'                           = 'http://www.ipdb.org/machine.cgi?id=3513'
    'Aladdin''s Castle (Bally 1976)'                                                   = 'http://www.ipdb.org/machine.cgi?id=40'
    'Alaska (Interflip 1978)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3888'
    'Algar (Williams 1980)'                                                            = 'http://www.ipdb.org/machine.cgi?id=42'
    'Ali (Stern 1980)'                                                                 = 'http://www.ipdb.org/machine.cgi?id=43'
    'Alice in Wonderland (Gottlieb 1948)'                                              = 'https://www.ipdb.org/machine.cgi?id=47'
    'Alien Poker (Williams 1980)'                                                      = 'http://www.ipdb.org/machine.cgi?id=48'
    'Alien Star (Gottlieb 1984)'                                                       = 'http://www.ipdb.org/machine.cgi?id=49'
    'Alien Warrior (LTD do Brasil 1982)'                                               = 'https://www.ipdb.org/machine.cgi?id=5882'
    'Alive (Brunswick 1978)'                                                           = 'http://www.ipdb.org/machine.cgi?id=50'
    'Aloha (Gottlieb 1961)'                                                            = 'https://www.ipdb.org/machine.cgi?id=62'
    'Amazon Hunt (Gottlieb 1983)'                                                      = 'http://www.ipdb.org/machine.cgi?id=66'
    'America 1492 (Juegos Populares 1986)'                                             = 'http://www.ipdb.org/machine.cgi?id=5013'
    'America''s Most Haunted (Spooky Pinball 2014)'                                    = 'https://www.ipdb.org/machine.cgi?id=6161'
    'Amigo (Bally 1974)'                                                               = 'https://www.ipdb.org/machine.cgi?id=71'
    'Andromeda (Game Plan 1985)'                                                       = 'http://www.ipdb.org/machine.cgi?id=73'
    'Andromeda - Tokyo 2074 Edition (Game Plan 1985)'                                  = 'http://www.ipdb.org/machine.cgi?id=73'
    'Antar (Playmatic 1979)'                                                           = 'https://www.ipdb.org/machine.cgi?id=3646'
    'Apache (Playmatic 1975)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4483'
    'Apache! (Taito do Brasil 1978)'                                                   = 'https://www.ipdb.org/machine.cgi?id=4660'
    'Apollo (Williams 1967)'                                                           = 'https://www.ipdb.org/machine.cgi?id=77'
    'Apollo 13 (Sega 1995)'                                                            = 'http://www.ipdb.org/machine.cgi?id=3592'
    'Aqualand (Juegos Populares 1986)'                                                 = 'http://www.ipdb.org/machine.cgi?id=3935'
    'Aquarius (Gottlieb 1970)'                                                         = 'http://www.ipdb.org/machine.cgi?id=79'
    'Arena (Gottlieb 1987)'                                                            = 'http://www.ipdb.org/machine.cgi?id=82'
    'Argosy (Williams 1977)'                                                           = 'http://www.ipdb.org/machine.cgi?id=84'
    'Arizona (LTD do Brasil 1977)'                                                     = 'https://www.ipdb.org/machine.cgi?id=5890'
    'Aspen (Brunswick 1979)'                                                           = 'http://www.ipdb.org/machine.cgi?id=3660'
    'Asteroid Annie and the Aliens (Gottlieb 1980)'                                    = 'http://www.ipdb.org/machine.cgi?id=98'
    'Astro (Gottlieb 1971)'                                                            = 'http://www.ipdb.org/machine.cgi?id=99'
    'Astronaut (Chicago Coin 1969)'                                                    = 'https://www.ipdb.org/machine.cgi?id=101'
    'Atlantis (Gottlieb 1975)'                                                         = 'http://www.ipdb.org/machine.cgi?id=105'
    'Atlantis (Bally 1989)'                                                            = 'http://www.ipdb.org/machine.cgi?id=106'
    'Atlantis (LTD do Brasil 1978)'                                                    = 'https://www.ipdb.org/machine.cgi?id=6712'
    'Atleta (Inder 1991)'                                                              = 'http://www.ipdb.org/machine.cgi?id=4095'
    'Attack from Mars (Bally 1995)'                                                    = 'https://www.ipdb.org/machine.cgi?id=3781'
    'Attila the Hun (Game Plan 1984)'                                                  = 'http://www.ipdb.org/machine.cgi?id=109'
    'Austin Powers (Stern 2001)'                                                       = 'https://www.ipdb.org/machine.cgi?id=4504'
    'Aztec (Williams 1976)'                                                            = 'http://www.ipdb.org/machine.cgi?id=119'
    'Aztec - High-Tap Edition (Williams 1976)'                                         = 'http://www.ipdb.org/machine.cgi?id=119'
    'BMX (Bally 1983)'                                                                 = 'https://www.ipdb.org/machine.cgi?id=335'
    'BMX - Radical Rick Edition (Bally 1983)'                                          = 'https://www.ipdb.org/machine.cgi?id=335'
    'BMX - RAD Edition (Bally 1983)'                                                   = 'https://www.ipdb.org/machine.cgi?id=335'
    'Baby Leland (Stoner 1933)'                                                        = 'https://www.ipdb.org/machine.cgi?id=123'
    'Baby Pac-Man (Bally 1982)'                                                        = 'http://www.ipdb.org/machine.cgi?id=125'
    'Back to the Future (Data East 1990)'                                              = 'https://www.ipdb.org/machine.cgi?id=126'
    'Bad Cats (Williams 1989)'                                                         = 'http://www.ipdb.org/machine.cgi?id=127'
    'Bad Girls (Gottlieb 1988)'                                                        = 'http://www.ipdb.org/machine.cgi?id=128'
    'Bad Girls - Alternate Edition (Gottlieb 1988)'                                    = 'http://www.ipdb.org/machine.cgi?id=128'
    'Balls-A-Poppin (Bally 1956)'                                                      = 'https://www.ipdb.org/machine.cgi?id=144'
    'Bally Hoo (Bally 1969)'                                                           = 'https://www.ipdb.org/machine.cgi?id=151'
    'Ballyhoo (Bally 1932)'                                                            = 'https://www.ipdb.org/machine.cgi?id=4817'
    'Band Wagon (Bally 1965)'                                                          = 'http://www.ipdb.org/machine.cgi?id=163'
    'Bank Shot (Gottlieb 1976)'                                                        = 'http://www.ipdb.org/machine.cgi?id=169'
    'Bank-A-Ball (Gottlieb 1965)'                                                      = 'http://www.ipdb.org/machine.cgi?id=170'
    'Bank-A-Ball (J.F. Linck 1932)'                                                    = 'https://www.ipdb.org/machine.cgi?id=6520'
    'Banzai Run (Williams 1988)'                                                       = 'http://www.ipdb.org/machine.cgi?id=175'
    'Barb Wire (Gottlieb 1996)'                                                        = 'http://www.ipdb.org/machine.cgi?id=3795'
    'Barbarella (Automaticos 1972)'                                                    = 'http://www.ipdb.org/machine.cgi?id=5809'
    'Barracora (Williams 1981)'                                                        = 'http://www.ipdb.org/machine.cgi?id=177'
    'Baseball (Gottlieb 1970)'                                                         = 'http://www.ipdb.org/machine.cgi?id=185'
    'Basketball (IDSA 1986)'                                                           = 'http://www.ipdb.org/machine.cgi?id=5023'
    'Bat-Em (In & Outdoor 1932)'                                                       = 'https://www.ipdb.org/machine.cgi?id=194'
    'Batman (Stern 2008)'                                                              = 'http://www.ipdb.org/machine.cgi?id=5307'
    'Batman (Data East 1991)'                                                          = 'http://www.ipdb.org/machine.cgi?id=195'
    'Batman (66 Premium) (Stern 2016)'                                                 = 'https://www.ipdb.org/machine.cgi?id=6354'
    'Batman Forever (Sega 1995)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3593'
    'Batter Up (Gottlieb 1970)'                                                        = 'https://www.ipdb.org/machine.cgi?id=197'
    'Baywatch (Sega 1995)'                                                             = 'http://www.ipdb.org/machine.cgi?id=2848'
    'Beat Time (Williams 1967)'                                                        = 'http://www.ipdb.org/machine.cgi?id=213'
    'Beat Time - Beatles Edition (Williams 1967)'                                      = 'http://www.ipdb.org/machine.cgi?id=213'
    'Beat the Clock (Bally 1985)'                                                      = 'http://www.ipdb.org/machine.cgi?id=212'
    'Beisbol (Maresa 1971)'                                                            = 'https://www.ipdb.org/machine.cgi?id=5320'
    'Bell Ringer (Gottlieb 1990)'                                                      = 'http://www.ipdb.org/machine.cgi?id=3602'
    'Ben Hur (Staal 1977)'                                                             = 'https://www.ipdb.org/machine.cgi?id=2855'
    'Big Bang Bar (Capcom 1996)'                                                       = 'http://www.ipdb.org/machine.cgi?id=4001'
    'Big Ben (Williams 1975)'                                                          = 'http://www.ipdb.org/machine.cgi?id=232'
    'Big Brave (Maresa 1974)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4634'
    'Big Brave - B&W Edition (Gottlieb 1974)'                                          = 'http://www.ipdb.org/machine.cgi?id=234'
    'Big Brave (Gottlieb 1974)'                                                        = 'http://www.ipdb.org/machine.cgi?id=234'
    'Big Buck Hunter Pro (Stern 2010)'                                                 = 'http://www.ipdb.org/machine.cgi?id=5513'
    'Big Casino (Gottlieb 1961)'                                                       = 'http://www.ipdb.org/machine.cgi?id=239'
    'Big Chief (Williams 1965)'                                                        = 'https://www.ipdb.org/machine.cgi?id=240'
    'Big Deal (Williams 1977)'                                                         = 'https://www.ipdb.org/machine.cgi?id=245'
    'Big Deal (Williams 1963)'                                                         = 'https://www.ipdb.org/machine.cgi?id=244'
    'Big Dick (Fabulous Fantasies 1996)'                                               = 'https://www.ipdb.org/machine.cgi?id=4539'
    'Big Game (Stern 1980)'                                                            = 'http://www.ipdb.org/machine.cgi?id=249'
    'Big Game (Rock-ola 1935)'                                                         = 'https://www.ipdb.org/machine.cgi?id=248'
    'Big Guns (Williams 1987)'                                                         = 'http://www.ipdb.org/machine.cgi?id=250'
    'Big Hit (Gottlieb 1977)'                                                          = 'https://www.ipdb.org/machine.cgi?id=253'
    'Big Horse (Maresa 1975)'                                                          = 'https://www.ipdb.org/machine.cgi?id=255'
    'Big House (Gottlieb 1989)'                                                        = 'http://www.ipdb.org/machine.cgi?id=256'
    'Big Indian (Gottlieb 1974)'                                                       = 'https://www.ipdb.org/machine.cgi?id=257'
    'Big Injun (Gottlieb 1974)'                                                        = 'https://www.ipdb.org/machine.cgi?id=257'
    'Big Shot (Gottlieb 1974)'                                                         = 'http://www.ipdb.org/machine.cgi?id=271'
    'Big Show (Bally 1974)'                                                            = 'https://www.ipdb.org/machine.cgi?id=275'
    'Big Star (Williams 1972)'                                                         = 'https://www.ipdb.org/machine.cgi?id=279'
    'Big Top (Gottlieb 1988)'                                                          = 'https://www.ipdb.org/machine.cgi?id=5347'
    'Big Town (Playmatic 1978)'                                                        = 'https://www.ipdb.org/machine.cgi?id=3607'
    'Big Valley (Bally 1970)'                                                          = 'http://www.ipdb.org/machine.cgi?id=289'
    'Black & Red (Inder 1975)'                                                         = 'https://www.ipdb.org/machine.cgi?id=4413'
    'Black Belt (Bally 1986)'                                                          = 'http://www.ipdb.org/machine.cgi?id=303'
    'Black Fever (Playmatic 1980)'                                                     = 'https://www.ipdb.org/machine.cgi?id=3645'
    'Black Gold (Williams 1975)'                                                       = 'http://www.ipdb.org/machine.cgi?id=306'
    'Black Hole (Gottlieb 1981)'                                                       = 'http://www.ipdb.org/machine.cgi?id=307'
    'Black Hole (LTD do Brasil 1982)'                                                  = 'https://www.ipdb.org/machine.cgi?id=5891'
    'Black Jack (SS) (Bally 1978)'                                                     = 'http://www.ipdb.org/machine.cgi?id=309'
    'Black Knight (Williams 1980)'                                                     = 'http://www.ipdb.org/machine.cgi?id=310'
    'Black Knight 2000 (Williams 1989)'                                                = 'http://www.ipdb.org/machine.cgi?id=311'
    'Black Knight Sword of Rage (Stern 2019)'                                          = 'https://www.ipdb.org/machine.cgi?id=6569'
    'Black Magic 4 (Recel 1980)'                                                       = 'https://www.ipdb.org/machine.cgi?id=3626'
    'Black Pyramid (Bally 1984)'                                                       = 'http://www.ipdb.org/machine.cgi?id=312'
    'Black Rose (Bally 1992)'                                                          = 'http://www.ipdb.org/machine.cgi?id=313'
    'Black Sheep Squadron (Astro Games 1979)'                                          = 'http://www.ipdb.org/machine.cgi?id=314'
    'Black Velvet (Game Plan 1978)'                                                    = 'https://www.ipdb.org/machine.cgi?id=315'
    'Blackout (Williams 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=317'
    'Blackwater 100 (Bally 1988)'                                                      = 'http://www.ipdb.org/machine.cgi?id=319'
    'Blue Chip (Williams 1976)'                                                        = 'http://www.ipdb.org/machine.cgi?id=325'
    'Blue Note (Gottlieb 1978)'                                                        = 'http://www.ipdb.org/machine.cgi?id=328'
    'Bobby Orr Power Play (Bally 1978)'                                                = 'http://www.ipdb.org/machine.cgi?id=1858'
    'Bon Voyage (Bally 1974)'                                                          = 'https://www.ipdb.org/machine.cgi?id=343'
    'Bone Busters Inc. (Gottlieb 1989)'                                                = 'http://www.ipdb.org/machine.cgi?id=347'
    'Boomerang (Bally 1974)'                                                           = 'https://www.ipdb.org/machine.cgi?id=354'
    'Boop-A-Doop (Pace 1932)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3653'
    'Border Town (Gottlieb 1940)'                                                      = 'https://www.ipdb.org/machine.cgi?id=357'
    'Bounty Hunter (Gottlieb 1985)'                                                    = 'http://www.ipdb.org/machine.cgi?id=361'
    'Bow and Arrow (EM) (Bally 1975)'                                                  = 'http://www.ipdb.org/machine.cgi?id=362'
    'Bow and Arrow (SS) (Bally 1974)'                                                  = 'https://www.ipdb.org/machine.cgi?id=4770'
    'Bowling - Alle Neune (NSM 1976)'                                                  = 'https://www.ipdb.org/machine.cgi?id=6037'
    'Bram Stoker''s Dracula - Blood Edition (Williams 1993)'                           = 'http://www.ipdb.org/machine.cgi?id=3072'
    'Bram Stoker''s Dracula (Williams 1993)'                                           = 'http://www.ipdb.org/machine.cgi?id=3072'
    'Brave Team (Inder 1985)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4480'
    'Break (Video Dens 1986)'                                                          = 'https://www.ipdb.org/machine.cgi?id=5569'
    'Breakshot (Capcom 1996)'                                                          = 'http://www.ipdb.org/machine.cgi?id=3784'
    'Bristol Hills (Gottlieb 1971)'                                                    = 'http://www.ipdb.org/machine.cgi?id=376'
    'Bronco (Gottlieb 1977)'                                                           = 'http://www.ipdb.org/machine.cgi?id=388'
    'Buccaneer (Gottlieb 1948)'                                                        = 'https://www.ipdb.org/machine.cgi?id=390'
    'Buccaneer (J. Esteban 1976)'                                                      = 'https://www.ipdb.org/machine.cgi?id=6276'
    'Buccaneer (Gottlieb 1976)'                                                        = 'http://www.ipdb.org/machine.cgi?id=391'
    'Buck Rogers (Gottlieb 1980)'                                                      = 'http://www.ipdb.org/machine.cgi?id=392'
    'Buckaroo (Gottlieb 1965)'                                                         = 'http://www.ipdb.org/machine.cgi?id=393'
    'Bugs Bunny''s Birthday Ball (Bally 1990)'                                         = 'http://www.ipdb.org/machine.cgi?id=396'
    'Bumper (Bill Port 1977)'                                                          = 'https://www.ipdb.org/machine.cgi?id=6194'
    'Bumper - B&W Edition (Bill Port 1977)'                                            = 'https://www.ipdb.org/machine.cgi?id=6194'
    'Bumper Pool (Gottlieb 1969)'                                                      = 'https://www.ipdb.org/machine.cgi?id=406'
    'Bunnyboard (Marble Games 1932)'                                                   = 'https://www.ipdb.org/machine.cgi?id=407'
    'Bushido (Inder 1993)'                                                             = 'http://www.ipdb.org/machine.cgi?id=4481'
    'CSI (Stern 2008)'                                                                 = 'http://www.ipdb.org/machine.cgi?id=5348'
    'Cabaret (Williams 1968)'                                                          = 'http://www.ipdb.org/machine.cgi?id=415'
    'Cactus Canyon (Bally 1998)'                                                       = 'https://www.ipdb.org/machine.cgi?id=4445'
    'Cactus Jack''s (Gottlieb 1991)'                                                   = 'http://www.ipdb.org/machine.cgi?id=416'
    'Caddie (Playmatic 1970)'                                                          = 'https://www.ipdb.org/machine.cgi?id=417'
    'Canada Dry (Gottlieb 1976)'                                                       = 'http://www.ipdb.org/machine.cgi?id=426'
    'Canasta 86 (Inder 1986)'                                                          = 'http://www.ipdb.org/machine.cgi?id=4097'
    'Cannes (Segasa 1976)'                                                             = 'https://www.ipdb.org/machine.cgi?id=428'
    'Capersville (Bally 1966)'                                                         = 'http://www.ipdb.org/machine.cgi?id=431'
    'Capt. Card (Gottlieb 1974)'                                                       = 'http://www.ipdb.org/machine.cgi?id=433'
    'Capt. Fantastic and the Brown Dirt Cowboy (Bally 1976)'                           = 'http://www.ipdb.org/machine.cgi?id=438'
    'Captain NEMO Dives Again - Steampunk Flyer Edition (Quetzal Pinball 2015)'        = 'https://www.ipdb.org/machine.cgi?id=6465'
    'Captain NEMO Dives Again (Quetzal Pinball 2015)'                                  = 'https://www.ipdb.org/machine.cgi?id=6465'
    'Car Hop (Gottlieb 1991)'                                                          = 'http://www.ipdb.org/machine.cgi?id=3676'
    'Card King (Gottlieb 1971)'                                                        = 'https://www.ipdb.org/machine.cgi?id=445'
    'Card Trix (Gottlieb 1970)'                                                        = 'http://www.ipdb.org/machine.cgi?id=446'
    'Card Whiz (Gottlieb 1976)'                                                        = 'http://www.ipdb.org/machine.cgi?id=447'
    'Carnival Queen (Bally 1958)'                                                      = 'https://www.ipdb.org/machine.cgi?id=456'
    'Casino (Williams 1958)'                                                           = 'https://www.ipdb.org/machine.cgi?id=463'
    'Catacomb (Stern 1981)'                                                            = 'http://www.ipdb.org/machine.cgi?id=469'
    'Cavalcade (Stoner 1935)'                                                          = 'http://www.ipdb.org/machine.cgi?id=473'
    'Cavaleiro Negro (Taito do Brasil 1980)'                                           = 'http://www.ipdb.org/machine.cgi?id=4568'
    'Cavalier (Recel 1979)'                                                            = 'https://www.ipdb.org/machine.cgi?id=474'
    'Caveman (Gottlieb 1982)'                                                          = 'http://www.ipdb.org/machine.cgi?id=475'
    'Centaur (Bally 1981)'                                                             = 'http://www.ipdb.org/machine.cgi?id=476'
    'Centigrade 37 (Gottlieb 1977)'                                                    = 'http://www.ipdb.org/machine.cgi?id=480'
    'Central Park (Gottlieb 1966)'                                                     = 'https://www.ipdb.org/machine.cgi?id=481'
    'Cerberus (Playmatic 1983)'                                                        = 'https://www.ipdb.org/machine.cgi?id=3004'
    'Champ (Bally 1974)'                                                               = 'http://www.ipdb.org/machine.cgi?id=486'
    'Chance (Playmatic 1974)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4878'
    'Chance (Playmatic 1978)'                                                          = 'http://www.ipdb.org/machine.cgi?id=491'
    'Charlie''s Angels (Gottlieb 1978)'                                                = 'http://www.ipdb.org/machine.cgi?id=492'
    'Charlie''s Angels (Gottlieb 1979)'                                                = 'https://www.ipdb.org/machine.cgi?id=5007'
    'Check (Recel 1975)'                                                               = 'https://www.ipdb.org/machine.cgi?id=495'
    'Check Mate (Recel 1975)'                                                          = 'https://www.ipdb.org/machine.cgi?id=496'
    'Check Mate (Taito do Brasil 1977)'                                                = 'https://www.ipdb.org/machine.cgi?id=5491'
    'Checkpoint (Data East 1991)'                                                      = 'http://www.ipdb.org/machine.cgi?id=498'
    'Cheetah (Stern 1980)'                                                             = 'http://www.ipdb.org/machine.cgi?id=500'
    'Chicago Cubs ''Triple Play'' (Gottlieb 1985)'                                     = 'http://www.ipdb.org/machine.cgi?id=502'
    'Circus (Brunswick 1980)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4937'
    'Circus (Gottlieb 1980)'                                                           = 'http://www.ipdb.org/machine.cgi?id=515'
    'Circus (Zaccaria 1977)'                                                           = 'http://www.ipdb.org/machine.cgi?id=518'
    'Circus (Bally 1973)'                                                              = 'https://www.ipdb.org/machine.cgi?id=521'
    'Cirqus Voltaire (Bally 1997)'                                                     = 'https://www.ipdb.org/machine.cgi?id=4059'
    'City Ship (J. Esteban 1978)'                                                      = 'https://www.ipdb.org/machine.cgi?id=5130'
    'City Slicker (Bally 1987)'                                                        = 'http://www.ipdb.org/machine.cgi?id=527'
    'Class of 1812 (Gottlieb 1991)'                                                    = 'http://www.ipdb.org/machine.cgi?id=528'
    'Cleopatra (SS) (Gottlieb 1977)'                                                   = 'http://www.ipdb.org/machine.cgi?id=532'
    'Close Encounters of the Third Kind (Gottlieb 1978)'                               = 'http://www.ipdb.org/machine.cgi?id=536'
    'Clown (Inder 1988)'                                                               = 'https://www.ipdb.org/machine.cgi?id=4093'
    'Clown (Playmatic 1971)'                                                           = 'https://www.ipdb.org/machine.cgi?id=5447'
    'Cobra (Playbar 1987)'                                                             = 'https://www.ipdb.org/machine.cgi?id=4124'
    'Cobra (Nuova Bell Games 1987)'                                                    = 'https://www.ipdb.org/machine.cgi?id=3026'
    'College Queens (Gottlieb 1969)'                                                   = 'http://www.ipdb.org/machine.cgi?id=543'
    'Columbia (LTD do Brasil 1983)'                                                    = 'https://www.ipdb.org/machine.cgi?id=5759'
    'Combination Rotation (Gottlieb 1982)'                                             = 'https://www.ipdb.org/machine.cgi?id=5331'
    'Comet (Williams 1985)'                                                            = 'http://www.ipdb.org/machine.cgi?id=548'
    'Conan (Rowamet 1983)'                                                             = 'http://www.ipdb.org/machine.cgi?id=4580'
    'Concorde (Emagar 1975)'                                                           = 'http://www.ipdb.org/machine.cgi?id=6024'
    'Congo (Williams 1995)'                                                            = 'http://www.ipdb.org/machine.cgi?id=3780'
    'Conquest 200 (Playmatic 1976)'                                                    = 'https://www.ipdb.org/machine.cgi?id=557'
    'Contact (Williams 1978)'                                                          = 'http://www.ipdb.org/machine.cgi?id=558'
    'Contact Master (PAMCO 1934)'                                                      = 'https://www.ipdb.org/machine.cgi?id=4457'
    'Contest (Gottlieb 1958)'                                                          = 'http://www.ipdb.org/machine.cgi?id=564'
    'Coronation (Gottlieb 1952)'                                                       = 'https://www.ipdb.org/machine.cgi?id=568'
    'Corsario (Inder 1989)'                                                            = 'http://www.ipdb.org/machine.cgi?id=4090'
    'Corvette (Bally 1994)'                                                            = 'http://www.ipdb.org/machine.cgi?id=570'
    'Cosmic (Taito do Brasil 1980)'                                                    = 'http://www.ipdb.org/machine.cgi?id=4567'
    'Cosmic Gunfight (Williams 1982)'                                                  = 'http://www.ipdb.org/machine.cgi?id=571'
    'Cosmic Princess (Stern 1979)'                                                     = 'http://www.ipdb.org/machine.cgi?id=3967'
    'Cosmic Venus (Tilt Movie 1978)'                                                   = 'https://www.ipdb.org/machine.cgi?id=5711'
    'Count-Down (Gottlieb 1979)'                                                       = 'http://www.ipdb.org/machine.cgi?id=573'
    'Counterforce (Gottlieb 1980)'                                                     = 'http://www.ipdb.org/machine.cgi?id=575'
    'Cow Poke (Gottlieb 1965)'                                                         = 'http://www.ipdb.org/machine.cgi?id=581'
    'Cowboy Eight Ball (LTD do Brasil 1981)'                                           = 'http://www.ipdb.org/machine.cgi?id=5132'
    'Cowboy Eight Ball 2 (LTD do Brasil 1981)'                                         = 'https://www.ipdb.org/machine.cgi?id=5734'
    'Creature from the Black Lagoon (Bally 1992)'                                      = 'https://www.ipdb.org/machine.cgi?id=588'
    'Creature from the Black Lagoon - B&W Edition (Bally 1992)'                        = 'https://www.ipdb.org/machine.cgi?id=588'
    'Creature from the Black Lagoon - Nude Edition (Bally 1992)'                       = 'https://www.ipdb.org/machine.cgi?id=588'
    'Crescendo (Gottlieb 1970)'                                                        = 'http://www.ipdb.org/machine.cgi?id=590'
    'Criterium 75 (Recel 1975)'                                                        = 'https://www.ipdb.org/machine.cgi?id=596'
    'Cross Town (Gottlieb 1966)'                                                       = 'https://www.ipdb.org/machine.cgi?id=601'
    'Crystal-Ball (Automaticos 1970)'                                                  = 'https://www.ipdb.org/machine.cgi?id=5498'
    'Cue (Stern 1982)'                                                                 = 'https://www.ipdb.org/machine.cgi?id=3873'
    'Cue Ball Wizard (Gottlieb 1992)'                                                  = 'http://www.ipdb.org/machine.cgi?id=610'
    'Cybernaut (Bally 1985)'                                                           = 'http://www.ipdb.org/machine.cgi?id=614'
    'Cyclone (Williams 1988)'                                                          = 'http://www.ipdb.org/machine.cgi?id=617'
    'Cyclopes (Game Plan 1985)'                                                        = 'http://www.ipdb.org/machine.cgi?id=619'
    'Dale Jr. (Stern 2007)'                                                            = 'http://www.ipdb.org/machine.cgi?id=5292'
    'Dark Rider (Geiger 1984)'                                                         = 'https://www.ipdb.org/machine.cgi?id=3968'
    'Dark Shadow (Nuova Bell Games 1986)'                                              = 'https://www.ipdb.org/machine.cgi?id=3699'
    'Darling (Williams 1973)'                                                          = 'http://www.ipdb.org/machine.cgi?id=640'
    'Deadly Weapon (Gottlieb 1990)'                                                    = 'http://www.ipdb.org/machine.cgi?id=645'
    'Dealer''s Choice (Williams 1973)'                                                 = 'https://www.ipdb.org/machine.cgi?id=649'
    'Defender (Williams 1982)'                                                         = 'http://www.ipdb.org/machine.cgi?id=651'
    'Demolition Man - Limited Cryo Edition (Williams 1994)'                            = 'http://www.ipdb.org/machine.cgi?id=662'
    'Demolition Man (Williams 1994)'                                                   = 'http://www.ipdb.org/machine.cgi?id=662'
    'Dennis Lillee''s Howzat! (Hankin 1980)'                                           = 'https://www.ipdb.org/machine.cgi?id=3909'
    'Devil Riders (Zaccaria 1984)'                                                     = 'http://www.ipdb.org/machine.cgi?id=672'
    'Devil''s Dare (Gottlieb 1982)'                                                    = 'http://www.ipdb.org/machine.cgi?id=673'
    'Diamond Jack (Gottlieb 1967)'                                                     = 'https://www.ipdb.org/machine.cgi?id=676'
    'Diamond Lady (Gottlieb 1988)'                                                     = 'http://www.ipdb.org/machine.cgi?id=678'
    'Dimension (Gottlieb 1971)'                                                        = 'http://www.ipdb.org/machine.cgi?id=680'
    'Diner (Williams 1990)'                                                            = 'http://www.ipdb.org/machine.cgi?id=681'
    'Dipsy Doodle (Williams 1970)'                                                     = 'http://www.ipdb.org/machine.cgi?id=683'
    'Dirty Harry (Williams 1995)'                                                      = 'http://www.ipdb.org/machine.cgi?id=684'
    'Disco (Stern 1977)'                                                               = 'https://www.ipdb.org/machine.cgi?id=685'
    'Disco Dancing (LTD do Brasil 1979)'                                               = 'https://www.ipdb.org/machine.cgi?id=5892'
    'Disco Fever (Williams 1978)'                                                      = 'https://www.ipdb.org/machine.cgi?id=686'
    'Disney TRON Legacy (Limited Edition) (Stern 2011)'                                = 'http://www.ipdb.org/machine.cgi?id=5682'
    'Disney TRON Legacy (Limited Edition) - PuP-Pack Edition (Stern 2011)'             = 'http://www.ipdb.org/machine.cgi?id=5682'
    'Dixieland (Bally 1968)'                                                           = 'https://www.ipdb.org/machine.cgi?id=692'
    'Doctor Who (Bally 1992)'                                                          = 'http://www.ipdb.org/machine.cgi?id=738'
    'Dogies (Bally 1968)'                                                              = 'http://www.ipdb.org/machine.cgi?id=696'
    'Dolly Parton (Bally 1979)'                                                        = 'http://www.ipdb.org/machine.cgi?id=698'
    'Dolphin (Chicago Coin 1974)'                                                      = 'http://www.ipdb.org/machine.cgi?id=699'
    'Domino (Gottlieb 1983)'                                                           = 'https://www.ipdb.org/machine.cgi?id=5334'
    'Domino (Gottlieb 1968)'                                                           = 'http://www.ipdb.org/machine.cgi?id=701'
    'Doodle Bug (Williams 1971)'                                                       = 'https://www.ipdb.org/machine.cgi?id=703'
    'Double Barrel (Williams 1961)'                                                    = 'https://www.ipdb.org/machine.cgi?id=709'
    'Double-Up (Bally 1970)'                                                           = 'http://www.ipdb.org/machine.cgi?id=4447'
    'Dr. Dude and His Excellent Ray (Bally 1990)'                                      = 'http://www.ipdb.org/machine.cgi?id=737'
    'Dracula (Stern 1979)'                                                             = 'http://www.ipdb.org/machine.cgi?id=728'
    'Dragon (Gottlieb 1978)'                                                           = 'https://www.ipdb.org/machine.cgi?id=4697'
    'Dragon (Interflip 1977)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3887'
    'Dragon (SS) (Gottlieb 1978)'                                                      = 'https://www.ipdb.org/machine.cgi?id=729'
    'Dragonette (Gottlieb 1954)'                                                       = 'https://www.ipdb.org/machine.cgi?id=730'
    'Dragonfist (Stern 1981)'                                                          = 'https://www.ipdb.org/machine.cgi?id=731'
    'Dragoon (Recreativos Franco 1977)'                                                = 'https://www.ipdb.org/machine.cgi?id=4872'
    'Drakor (Taito do Brasil 1979)'                                                    = 'http://www.ipdb.org/machine.cgi?id=4569'
    'Drop-A-Card (Gottlieb 1971)'                                                      = 'http://www.ipdb.org/machine.cgi?id=735'
    'Dungeons & Dragons (Bally 1987)'                                                  = 'http://www.ipdb.org/machine.cgi?id=743'
    'Duotron (Gottlieb 1974)'                                                          = 'http://www.ipdb.org/machine.cgi?id=744'
    'Dutch Pool (A.B.T. 1931)'                                                         = 'https://www.ipdb.org/machine.cgi?id=747'
    'Eager Beaver (Williams 1965)'                                                     = 'https://www.ipdb.org/machine.cgi?id=752'
    'Earth Wind Fire (Zaccaria 1981)'                                                  = 'http://www.ipdb.org/machine.cgi?id=3611'
    'Earthshaker (Williams 1989)'                                                      = 'http://www.ipdb.org/machine.cgi?id=753'
    'Eclipse (Gottlieb 1982)'                                                          = 'http://www.ipdb.org/machine.cgi?id=756'
    'Egg Head (Gottlieb 1961)'                                                         = 'https://www.ipdb.org/machine.cgi?id=758'
    'Eight Ball (Bally 1977)'                                                          = 'http://www.ipdb.org/machine.cgi?id=760'
    'Eight Ball Champ (Bally 1985)'                                                    = 'http://www.ipdb.org/machine.cgi?id=761'
    'El Dorado (Gottlieb 1975)'                                                        = 'http://www.ipdb.org/machine.cgi?id=766'
    'El Dorado City of Gold (Gottlieb 1984)'                                           = 'http://www.ipdb.org/machine.cgi?id=767'
    'Electra-Pool (Gottlieb 1965)'                                                     = 'https://www.ipdb.org/machine.cgi?id=779'
    'Elektra (Bally 1981)'                                                             = 'http://www.ipdb.org/machine.cgi?id=778'
    'Elite Guard (Gottlieb 1968)'                                                      = 'https://www.ipdb.org/machine.cgi?id=780'
    'Elvira and the Party Monsters (Bally 1989)'                                       = 'http://www.ipdb.org/machine.cgi?id=782'
    'Elvira and the Party Monsters - Nude Edition (Bally 1989)'                        = 'http://www.ipdb.org/machine.cgi?id=782'
    'Elvis (Stern 2004)'                                                               = 'http://www.ipdb.org/machine.cgi?id=4983'
    'Elvis Gold (Limited Edition) (Stern 2004)'                                        = 'https://www.ipdb.org/machine.cgi?id=6032'
    'Embryon (Bally 1981)'                                                             = 'http://www.ipdb.org/machine.cgi?id=783'
    'Escape from the Lost World (Bally 1988)'                                          = 'http://www.ipdb.org/machine.cgi?id=789'
    'Evel Knievel (Bally 1977)'                                                        = 'http://www.ipdb.org/machine.cgi?id=4499'
    'Evil Fight (Playmatic 1980)'                                                      = 'https://www.ipdb.org/machine.cgi?id=3085'
    'Excalibur (Gottlieb 1988)'                                                        = 'http://www.ipdb.org/machine.cgi?id=795'
    'Eye Of The Tiger (Gottlieb 1978)'                                                 = 'https://www.ipdb.org/machine.cgi?id=802'
    'F-14 Tomcat (Williams 1987)'                                                      = 'http://www.ipdb.org/machine.cgi?id=804'
    'FJ (Hankin 1978)'                                                                 = 'http://www.ipdb.org/machine.cgi?id=3627'
    'Faces (Sonic 1976)'                                                               = 'http://www.ipdb.org/machine.cgi?id=806'
    'Faeton (Juegos Populares 1985)'                                                   = 'http://www.ipdb.org/machine.cgi?id=3087'
    'Fair Fight (Recel 1978)'                                                          = 'https://www.ipdb.org/machine.cgi?id=808'
    'Family Guy (Stern 2007)'                                                          = 'http://www.ipdb.org/machine.cgi?id=5219'
    'Fan-Tas-Tic (Williams 1972)'                                                      = 'https://www.ipdb.org/machine.cgi?id=820'
    'Far Out (Gottlieb 1974)'                                                          = 'http://www.ipdb.org/machine.cgi?id=823'
    'Farfalla (Zaccaria 1983)'                                                         = 'http://www.ipdb.org/machine.cgi?id=824'
    'Farwest (Fliperbol 1980)'                                                         = 'https://www.ipdb.org/machine.cgi?id=4593'
    'Fashion Show (Gottlieb 1962)'                                                     = 'https://www.ipdb.org/machine.cgi?id=825'
    'Fast Draw (Gottlieb 1975)'                                                        = 'http://www.ipdb.org/machine.cgi?id=828'
    'Fathom (Bally 1981)'                                                              = 'http://www.ipdb.org/machine.cgi?id=829'
    'Fathom - LED Edition (Bally 1981)'                                                = 'http://www.ipdb.org/machine.cgi?id=829'
    'Fifteen (Inder 1974)'                                                             = 'https://www.ipdb.org/machine.cgi?id=4409'
    'Fire Action (Taito do Brasil 1980)'                                               = 'http://www.ipdb.org/machine.cgi?id=4570'
    'Fire Action De Luxe (Taito do Brasil 1983)'                                       = 'http://www.ipdb.org/machine.cgi?id=4552'
    'Fire Queen (Gottlieb 1977)'                                                       = 'http://www.ipdb.org/machine.cgi?id=851'
    'Fire! (Williams 1987)'                                                            = 'http://www.ipdb.org/machine.cgi?id=859'
    'Fireball (Bally 1972)'                                                            = 'http://www.ipdb.org/machine.cgi?id=852'
    'Fireball Classic (Bally 1985)'                                                    = 'https://www.ipdb.org/machine.cgi?id=853'
    'Fireball II (Bally 1981)'                                                         = 'http://www.ipdb.org/machine.cgi?id=854'
    'Firecracker (Bally 1971)'                                                         = 'http://www.ipdb.org/machine.cgi?id=855'
    'Firepower (Williams 1980)'                                                        = 'http://www.ipdb.org/machine.cgi?id=856'
    'Firepower II (Williams 1983)'                                                     = 'http://www.ipdb.org/machine.cgi?id=857'
    'Firepower vs. A.I. (Williams 1980)'                                               = 'http://www.ipdb.org/machine.cgi?id=856'
    'Fish Tales (Williams 1992)'                                                       = 'http://www.ipdb.org/machine.cgi?id=861'
    'Flash (Williams 1979)'                                                            = 'http://www.ipdb.org/machine.cgi?id=871'
    'Flash Dragon (Playmatic 1986)'                                                    = 'https://www.ipdb.org/machine.cgi?id=3616'
    'Flash Gordon (Bally 1981)'                                                        = 'http://www.ipdb.org/machine.cgi?id=874'
    'Flashman (Sport matic 1984)'                                                      = 'https://www.ipdb.org/machine.cgi?id=5218'
    'Fleet Jr. (Bally 1934)'                                                           = 'https://www.ipdb.org/machine.cgi?id=880'
    'Flicker (Bally 1975)'                                                             = 'https://www.ipdb.org/machine.cgi?id=883'
    'Flight 2000 (Stern 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=887'
    'Flip Flop (Bally 1976)'                                                           = 'https://www.ipdb.org/machine.cgi?id=889'
    'Flip a Card (Gottlieb 1970)'                                                      = 'http://www.ipdb.org/machine.cgi?id=890'
    'Flipper Fair (Gottlieb 1961)'                                                     = 'https://www.ipdb.org/machine.cgi?id=894'
    'Flipper Football (Capcom 1996)'                                                   = 'http://www.ipdb.org/machine.cgi?id=3945'
    'Flipper Pool (Gottlieb 1965)'                                                     = 'https://www.ipdb.org/machine.cgi?id=896'
    'Flying Carpet (Gottlieb 1972)'                                                    = 'http://www.ipdb.org/machine.cgi?id=899'
    'Flying Chariots (Gottlieb 1963)'                                                  = 'https://www.ipdb.org/machine.cgi?id=901'
    'Flying Turns (Midway 1964)'                                                       = 'http://www.ipdb.org/machine.cgi?id=910'
    'Football (Taito do Brasil 1979)'                                                  = 'https://www.ipdb.org/machine.cgi?id=5199'
    'Force (LTD do Brasil 1979)'                                                       = 'https://www.ipdb.org/machine.cgi?id=5893'
    'Force II (Gottlieb 1981)'                                                         = 'http://www.ipdb.org/machine.cgi?id=916'
    'Four Million B.C. (Bally 1971)'                                                   = 'http://www.ipdb.org/machine.cgi?id=935'
    'Four Seasons (Gottlieb 1968)'                                                     = 'https://www.ipdb.org/machine.cgi?id=939'
    'Frank Thomas'' Big Hurt (Gottlieb 1995)'                                          = 'https://www.ipdb.org/machine.cgi?id=3591'
    'Freddy - A Nightmare on Elm Street (Gottlieb 1994)'                               = 'http://www.ipdb.org/machine.cgi?id=948'
    'Free Fall (Gottlieb 1974)'                                                        = 'http://www.ipdb.org/machine.cgi?id=949'
    'Freedom (EM) (Bally 1976)'                                                        = 'http://www.ipdb.org/machine.cgi?id=952'
    'Freedom (SS) (Bally 1976)'                                                        = 'https://www.ipdb.org/machine.cgi?id=4500'
    'Freefall (Stern 1981)'                                                            = 'http://www.ipdb.org/machine.cgi?id=953'
    'Frontier (Bally 1980)'                                                            = 'http://www.ipdb.org/machine.cgi?id=959'
    'Full (Recreativos Franco 1977)'                                                   = 'https://www.ipdb.org/machine.cgi?id=4707'
    'Full House (Williams 1966)'                                                       = 'https://www.ipdb.org/machine.cgi?id=961'
    'Full Throttle (Original 2023)'                                                    = 'https://www.ipdb.org/machine.cgi?id=6301'
    'Fun Fair (Gottlieb 1968)'                                                         = 'https://www.ipdb.org/machine.cgi?id=964'
    'Fun Land (Gottlieb 1968)'                                                         = 'http://www.ipdb.org/machine.cgi?id=973'
    'Fun Park (Gottlieb 1968)'                                                         = 'http://www.ipdb.org/machine.cgi?id=968'
    'Fun-Fest (Williams 1972)'                                                         = 'https://www.ipdb.org/machine.cgi?id=972'
    'Funhouse (Williams 1990)'                                                         = 'http://www.ipdb.org/machine.cgi?id=966'
    'Future Spa (Bally 1979)'                                                          = 'http://www.ipdb.org/machine.cgi?id=974'
    'Galaxie (Gottlieb 1971)'                                                          = 'https://www.ipdb.org/machine.cgi?id=978'
    'Galaxy (Sega 1973)'                                                               = 'https://www.ipdb.org/machine.cgi?id=979'
    'Galaxy (Stern 1980)'                                                              = 'http://www.ipdb.org/machine.cgi?id=980'
    'Galaxy Play (CIC Play 1986)'                                                      = 'http://www.ipdb.org/machine.cgi?id=4631'
    'Gamatron (Sonic 1986)'                                                            = 'https://www.ipdb.org/machine.cgi?id=3116'
    'Gamatron (Pinstar 1985)'                                                          = 'https://www.ipdb.org/machine.cgi?id=984'
    'Game of Thrones (Limited Edition) (Stern 2015)'                                   = 'https://www.ipdb.org/machine.cgi?id=6309'
    'Gaucho (Gottlieb 1963)'                                                           = 'https://www.ipdb.org/machine.cgi?id=988'
    'Gay 90''s (Williams 1970)'                                                        = 'http://www.ipdb.org/machine.cgi?id=989'
    'Gemini (Gottlieb 1978)'                                                           = 'http://www.ipdb.org/machine.cgi?id=995'
    'Gemini 2000 (Taito do Brasil 1982)'                                               = 'http://www.ipdb.org/machine.cgi?id=4579'
    'Genesis (Gottlieb 1986)'                                                          = 'http://www.ipdb.org/machine.cgi?id=996'
    'Genie (Gottlieb 1979)'                                                            = 'http://www.ipdb.org/machine.cgi?id=997'
    'Genie - Fuzzel Physics Edition (Gottlieb 1979)'                                   = 'http://www.ipdb.org/machine.cgi?id=997'
    'Ghostbusters (Limited Edition) (Stern 2016)'                                      = 'http://www.ipdb.org/machine.cgi?id=6334'
    'Gigi (Gottlieb 1963)'                                                             = 'http://www.ipdb.org/machine.cgi?id=1003'
    'Gilligan''s Island (Bally 1991)'                                                  = 'http://www.ipdb.org/machine.cgi?id=1004'
    'Gladiators (Gottlieb 1993)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1011'
    'Godzilla (Sega 1998)'                                                             = 'http://www.ipdb.org/machine.cgi?id=4443'
    'Goin'' Nuts (Gottlieb 1983)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1021'
    'Gold Ball (Bally 1983)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1024'
    'Gold Crown (Pierce 1932)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1026'
    'Gold Rush (Williams 1971)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1036'
    'Gold Star (Gottlieb 1954)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1038'
    'Gold Strike (Gottlieb 1975)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1042'
    'Gold Wings (Gottlieb 1986)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1043'
    'Golden Arrow (Gottlieb 1977)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1044'
    'Golden Cue (Sega 1998)'                                                           = 'https://www.ipdb.org/machine.cgi?id=4383'
    'Goldeneye (Sega 1996)'                                                            = 'http://www.ipdb.org/machine.cgi?id=3792'
    'Gorgar (Williams 1979)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1062'
    'Gork (Taito do Brasil 1982)'                                                      = 'http://www.ipdb.org/machine.cgi?id=4590'
    'Grand Casino (J.P. Seeburg 1934)'                                                 = 'https://www.ipdb.org/machine.cgi?id=4194'
    'Grand Lizard (Williams 1986)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1070'
    'Grand Prix (Williams 1976)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1072'
    'Grand Prix (Stern 2005)'                                                          = 'https://www.ipdb.org/machine.cgi?id=5120'
    'Grand Slam (Gottlieb 1972)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1078'
    'Grand Slam (Bally 1983)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1079'
    'Grand Tour (Bally 1964)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1081'
    'Grande Domino (Gottlieb 1968)'                                                    = 'https://www.ipdb.org/machine.cgi?id=1069'
    'Granny and the Gators (Bally 1984)'                                               = 'http://www.ipdb.org/machine.cgi?id=1083'
    'Gridiron (Gottlieb 1977)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1089'
    'Groovy (Gottlieb 1970)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1091'
    'Guardians of the Galaxy (Pro) (Stern 2017)'                                       = 'https://www.ipdb.org/machine.cgi?id=6474'
    'Gulfstream (Williams 1973)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1094'
    'Gun Men (Staal 1979)'                                                             = 'https://www.ipdb.org/machine.cgi?id=3131'
    'Guns N'' Roses (Data East 1994)'                                                  = 'http://www.ipdb.org/machine.cgi?id=1100'
    'Halley Comet (Juegos Populares 1986)'                                             = 'https://www.ipdb.org/machine.cgi?id=3936'
    'Halley Comet - Alternate Plastics Edition (Juegos Populares 1986)'                = 'https://www.ipdb.org/machine.cgi?id=3936'
    'Hang Glider (Bally 1976)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1112'
    'Hardbody (Bally 1987)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1122'
    'Harlem Globetrotters on Tour (Bally 1979)'                                        = 'http://www.ipdb.org/machine.cgi?id=1125'
    'Harley-Davidson (Bally 1991)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1126'
    'Harley-Davidson (Sega 1999)'                                                      = 'http://www.ipdb.org/machine.cgi?id=4453'
    'Harmony (Gottlieb 1967)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1127'
    'Haunted Hotel (LTD do Brasil 1983)'                                               = 'https://www.ipdb.org/machine.cgi?id=5704'
    'Haunted House (Gottlieb 1982)'                                                    = 'http://www.ipdb.org/machine.cgi?id=1133'
    'Hawkman (Taito do Brasil 1983)'                                                   = 'http://www.ipdb.org/machine.cgi?id=4512'
    'Hayburners (Williams 1951)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1142'
    'Hearts Gain (Inder 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=4406'
    'Hearts and Spades (Gottlieb 1969)'                                                = 'http://www.ipdb.org/machine.cgi?id=1145'
    'Heat Wave (Williams 1964)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1148'
    'Heavy Metal (Rowamet 1981)'                                                       = 'http://www.ipdb.org/machine.cgi?id=5175'
    'Heavy Metal Meltdown (Bally 1987)'                                                = 'http://www.ipdb.org/machine.cgi?id=1150'
    'Hercules (Atari 1979)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1155'
    'Hi-Deal (Bally 1975)'                                                             = 'https://www.ipdb.org/machine.cgi?id=1157'
    'Hi-Diver (Gottlieb 1959)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1165'
    'Hi-Lo (Gottlieb 1969)'                                                            = 'https://www.ipdb.org/machine.cgi?id=1184'
    'Hi-Lo Ace (Bally 1973)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1187'
    'Hi-Score (Gottlieb 1967)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1160'
    'Hi-Score Pool (Chicago Coin 1971)'                                                = 'http://www.ipdb.org/machine.cgi?id=1161'
    'Hi-Skor (Hi-Skor 1932)'                                                           = 'https://www.ipdb.org/machine.cgi?id=5225'
    'High Hand (Gottlieb 1973)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1173'
    'High Roller Casino (Stern 2001)'                                                  = 'http://www.ipdb.org/machine.cgi?id=4502'
    'High Seas (Gottlieb 1976)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1175'
    'High Speed (Williams 1986)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1176'
    'Hit the Deck (Gottlieb 1978)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1201'
    'Hokus Pokus (Bally 1976)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1206'
    'Hollywood Heat (Gottlieb 1986)'                                                   = 'http://www.ipdb.org/machine.cgi?id=1219'
    'Home Run (Gottlieb 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1224'
    'Honey (Williams 1971)'                                                            = 'https://www.ipdb.org/machine.cgi?id=1230'
    'Hook (Data East 1992)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1233'
    'Hoops (Gottlieb 1991)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1235'
    'Hootenanny (Bally 1963)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1236'
    'Horseshoe (A.B.T. 1931)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3158'
    'Hot Ball (Taito do Brasil 1979)'                                                  = 'https://www.ipdb.org/machine.cgi?id=4665'
    'Hot Hand (Stern 1979)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1244'
    'Hot Line (Williams 1966)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1245'
    'Hot Shot (Gottlieb 1973)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1247'
    'Hot Shots (Gottlieb 1989)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1248'
    'Hot Tip - Less Reflections Edition (Williams 1977)'                               = 'http://www.ipdb.org/machine.cgi?id=3163'
    'Hot Tip (Williams 1977)'                                                          = 'http://www.ipdb.org/machine.cgi?id=3163'
    'Hotdoggin'' (Bally 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1243'
    'House of Diamonds (Zaccaria 1978)'                                                = 'https://www.ipdb.org/machine.cgi?id=3165'
    'Humpty Dumpty (Gottlieb 1947)'                                                    = 'http://www.ipdb.org/machine.cgi?id=1254'
    'Hunter (Jennings 1935)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1255'
    'Hurricane (Williams 1991)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1257'
    'Hustler (LTD do Brasil 1980)'                                                     = 'https://www.ipdb.org/machine.cgi?id=6706'
    'Hyperball - Analog Mouse Edition (Williams 1981)'                                 = 'http://www.ipdb.org/machine.cgi?id=3169'
    'Hyperball - Analog Joystick Edition (Williams 1981)'                              = 'http://www.ipdb.org/machine.cgi?id=3169'
    'Hyperball (Williams 1981)'                                                        = 'http://www.ipdb.org/machine.cgi?id=3169'
    'Ice Cold Beer (Taito 1983)'                                                       = 'https://www.ipdb.org/machine.cgi?id=6802'
    'Ice Fever (Gottlieb 1985)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1260'
    'Impacto (Recreativos Franco 1975)'                                                = 'http://www.ipdb.org/machine.cgi?id=4868'
    'Independence Day (Sega 1996)'                                                     = 'http://www.ipdb.org/machine.cgi?id=3878'
    'Indiana Jones (Stern 2008)'                                                       = 'https://www.ipdb.org/machine.cgi?id=5306'
    'Indiana Jones - The Pinball Adventure (Williams 1993)'                            = 'https://www.ipdb.org/machine.cgi?id=1267'
    'Indianapolis 500 (Bally 1995)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2853'
    'Iron Balls (Unidesa 1987)'                                                        = 'http://www.ipdb.org/machine.cgi?id=4426'
    'Iron Maiden (Stern 1982)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1270'
    'Iron Man (Stern 2010)'                                                            = 'http://www.ipdb.org/machine.cgi?id=5550'
    'Iron Man (Pro Vault Edition) (Stern 2014)'                                        = 'https://www.ipdb.org/machine.cgi?id=6154'
    'JP''s Addams Family (Bally 1992)'                                                 = 'https://www.ipdb.org/machine.cgi?id=20'
    'JP''s Captain Fantastic (Bally 1976)'                                             = 'http://www.ipdb.org/machine.cgi?id=438'
    'JP''s Cyclone (Original 2022)'                                                    = 'https://www.ipdb.org/machine.cgi?id=617'
    'JP''s Grand Prix (Stern 2005)'                                                    = 'http://www.ipdb.org/machine.cgi?id=5120'
    'JP''s Indiana Jones (Stern 2008)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5306'
    'JP''s Iron Man 2 - Armored Adventures (Original 2018)'                            = 'http://www.ipdb.org/machine.cgi?id=6154'
    'JP''s Mephisto (Cirsa 1987)'                                                      = 'http://www.ipdb.org/machine.cgi?id=4077'
    'JP''s Metallica Pro (Stern 2013)'                                                 = 'https://www.ipdb.org/machine.cgi?id=6028'
    'JP''s Motor Show (Original 2017)'                                                 = 'http://www.ipdb.org/machine.cgi?id=3631'
    'JP''s Nascar Race (Original 2015)'                                                = 'http://www.ipdb.org/machine.cgi?id=5093'
    'JP''s Seawitch (Stern 1980)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2089'
    'JP''s Spider-Man (Original 2018)'                                                 = 'http://www.ipdb.org/machine.cgi?id=5237'
    'JP''s Star Trek (Enterprise Limited Edition) (Original 2020)'                     = 'https://www.ipdb.org/machine.cgi?id=6045'
    'JP''s Street Fighter II (Original 2016)'                                          = 'http://www.ipdb.org/machine.cgi?id=2403'
    'JP''s Terminator 2 (Original 2020)'                                               = 'http://www.ipdb.org/machine.cgi?id=2524'
    'JP''s Terminator 3 (Stern 2003)'                                                  = 'http://www.ipdb.org/machine.cgi?id=4787'
    'JP''s The Avengers (Original 2019)'                                               = 'http://www.ipdb.org/machine.cgi?id=5938'
    'JP''s The Lord of the Rings (Stern 2003)'                                         = 'http://www.ipdb.org/machine.cgi?id=4858'
    'JP''s The Lost World Jurassic Park (Original 2020)'                               = 'http://www.ipdb.org/machine.cgi?id=4136'
    'JP''s The Walking Dead (Original 2021)'                                           = 'https://www.ipdb.org/machine.cgi?id=6155'
    'JP''s Transformers (Original 2018)'                                               = 'http://www.ipdb.org/machine.cgi?id=5709'
    'JP''s Whoa Nellie! Big Juicy Melons (Original 2022)'                              = 'https://www.ipdb.org/machine.cgi?id=5863'
    'Jack in the Box (Gottlieb 1973)'                                                  = 'http://www.ipdb.org/machine.cgi?id=1277'
    'Jack-Bot (Williams 1995)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3619'
    'Jackpot (Williams 1971)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1279'
    'Jacks Open (Gottlieb 1977)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1281'
    'Jacks to Open (Gottlieb 1984)'                                                    = 'https://www.ipdb.org/machine.cgi?id=1282'
    'Jake Mate (Recel 1974)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1283'
    'Jalisco (Recreativos Franco 1976)'                                                = 'https://www.ipdb.org/machine.cgi?id=4667'
    'Jalopy (Williams 1951)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1284'
    'James Bond 007 (Gottlieb 1980)'                                                   = 'http://www.ipdb.org/machine.cgi?id=1286'
    'James Cameron''s Avatar (Stern 2010)'                                             = 'http://www.ipdb.org/machine.cgi?id=5618'
    'Jet Spin (Gottlieb 1977)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1290'
    'Jive Time (Williams 1970)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1298'
    'Johnny Mnemonic (Williams 1995)'                                                  = 'http://www.ipdb.org/machine.cgi?id=3683'
    'Joker (Gottlieb 1950)'                                                            = 'https://www.ipdb.org/machine.cgi?id=1304'
    'Joker Poker (EM) (Gottlieb 1978)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5078'
    'Joker Poker (SS) (Gottlieb 1978)'                                                 = 'http://www.ipdb.org/machine.cgi?id=1306'
    'Joker Wild (Bally 1970)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3573'
    'Jokerz! (Williams 1988)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1308'
    'Jolly Park (Spinball S.A.L. 1996)'                                                = 'http://www.ipdb.org/machine.cgi?id=4618'
    'Jolly Roger (Williams 1967)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1314'
    'Joust (Williams 1983)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1316'
    'Joust (Bally 1969)'                                                               = 'https://www.ipdb.org/machine.cgi?id=1317'
    'Jubilee (Williams 1973)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1321'
    'Judge Dredd (Bally 1993)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1322'
    'Jumping Jack (Gottlieb 1973)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1329'
    'Jungle (Gottlieb 1972)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1332'
    'Jungle King (Gottlieb 1973)'                                                      = 'https://www.ipdb.org/machine.cgi?id=1336'
    'Jungle Life (Gottlieb 1972)'                                                      = 'https://www.ipdb.org/machine.cgi?id=1337'
    'Jungle Lord (Williams 1981)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1338'
    'Jungle Princess (Gottlieb 1977)'                                                  = 'http://www.ipdb.org/machine.cgi?id=1339'
    'Jungle Queen (Gottlieb 1977)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1340'
    'Junk Yard (Williams 1996)'                                                        = 'http://www.ipdb.org/machine.cgi?id=4014'
    'Jurassic Park (Data East 1993)'                                                   = 'https://www.ipdb.org/machine.cgi?id=1343'
    'KISS (Bally 1979)'                                                                = 'http://www.ipdb.org/machine.cgi?id=1386'
    'KISS - PuP-Pack Edition (Bally 1979)'                                             = 'http://www.ipdb.org/machine.cgi?id=1386'
    'KISS (Pro) - PuP-Pack Edition (Stern 2015)'                                       = 'https://www.ipdb.org/machine.cgi?id=6267'
    'KISS (Pro) (Stern 2015)'                                                          = 'https://www.ipdb.org/machine.cgi?id=6267'
    'Kick Off (Bally 1977)'                                                            = 'https://www.ipdb.org/machine.cgi?id=1365'
    'Kickoff (Williams 1967)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1362'
    'King Kong (Data East 1990)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3194'
    'King Kong (LTD do Brasil 1978)'                                                   = 'https://www.ipdb.org/machine.cgi?id=5894'
    'King Kool (Gottlieb 1972)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1371'
    'King Pin (Gottlieb 1973)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1374'
    'King Pin (Williams 1962)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1375'
    'King Rock (Gottlieb 1972)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1377'
    'King Tut (Bally 1969)'                                                            = 'https://www.ipdb.org/machine.cgi?id=1378'
    'King of Diamonds (Gottlieb 1967)'                                                 = 'http://www.ipdb.org/machine.cgi?id=1372'
    'Kingdom (J. Esteban 1980)'                                                        = 'https://www.ipdb.org/machine.cgi?id=5168'
    'Kingpin (Capcom 1996)'                                                            = 'http://www.ipdb.org/machine.cgi?id=4000'
    'Kings & Queens (Gottlieb 1965)'                                                   = 'http://www.ipdb.org/machine.cgi?id=1381'
    'Kings of Steel (Bally 1984)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1382'
    'Klondike (Williams 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1388'
    'Knock Out (Gottlieb 1950)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1391'
    'Krull (Gottlieb 1983)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1397'
    'Lady Death (Geiger 1983)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3972'
    'Lady Luck (Taito do Brasil 1980)'                                                 = 'http://www.ipdb.org/machine.cgi?id=5010'
    'Lady Luck (Recel 1976)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1405'
    'Lady Luck (Bally 1986)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1402'
    'Lap by Lap (Inder 1986)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4098'
    'Lariat (Gottlieb 1969)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1412'
    'Laser Ball (Williams 1979)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1413'
    'Laser Cue (Williams 1984)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1414'
    'Last Action Hero (Data East 1993)'                                                = 'http://www.ipdb.org/machine.cgi?id=1416'
    'Last Lap (Playmatic 1978)'                                                        = 'http://www.ipdb.org/machine.cgi?id=3207'
    'Lawman (Gottlieb 1971)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1419'
    'Lazer Lord (Stern 1982)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1421'
    'Lectronamo (Stern 1978)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1429'
    'Lethal Weapon 3 (Data East 1992)'                                                 = 'http://www.ipdb.org/machine.cgi?id=1433'
    'Liberty Bell (Williams 1977)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1436'
    'Lightning (Stern 1981)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1441'
    'Lightning Ball (Gottlieb 1959)'                                                   = 'https://www.ipdb.org/machine.cgi?id=1442'
    'Lights...Camera...Action! (Gottlieb 1989)'                                        = 'https://www.ipdb.org/machine.cgi?id=1445'
    'Line Drive (Williams 1972)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1447'
    'Little Chief (Williams 1975)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1458'
    'Little Joe (Bally 1972)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1460'
    'Loch Ness Monster (Game Plan 1985)'                                               = 'https://www.ipdb.org/machine.cgi?id=1465'
    'Locomotion (Zaccaria 1981)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3217'
    'Lortium (Juegos Populares 1987)'                                                  = 'https://www.ipdb.org/machine.cgi?id=4104'
    'Lost World (Bally 1978)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1476'
    'Lost in Space (Sega 1998)'                                                        = 'http://www.ipdb.org/machine.cgi?id=4442'
    'Love Bug (Williams 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1480'
    'Luck Smile (Inder 1976)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3886'
    'Luck Smile - 4 Player Edition (Inder 1976)'                                       = 'https://www.ipdb.org/machine.cgi?id=3886'
    'Lucky Ace (Williams 1974)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1483'
    'Lucky Hand (Gottlieb 1977)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1488'
    'Lucky Seven (Williams 1978)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1491'
    'Lucky Strike (Taito do Brasil 1978)'                                              = 'https://www.ipdb.org/machine.cgi?id=5492'
    'Lucky Strike (Gottlieb 1975)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1497'
    'Lunelle (Taito do Brasil 1981)'                                                   = 'http://www.ipdb.org/machine.cgi?id=4591'
    'Mac Jungle (MAC 1987)'                                                            = 'https://www.ipdb.org/machine.cgi?id=3187'
    'Mac''s Galaxy (MAC 1986)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3455'
    'Mach 2.0 Two (Spinball S.A.L. 1995)'                                              = 'https://www.ipdb.org/machine.cgi?id=4617'
    'Mad Race (Playmatic 1985)'                                                        = 'http://www.ipdb.org/machine.cgi?id=3445'
    'Magic (Stern 1979)'                                                               = 'http://www.ipdb.org/machine.cgi?id=1509'
    'Magic Castle (Zaccaria 1984)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1511'
    'Magic Circle (Bally 1965)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1513'
    'Magic City (Williams 1967)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1514'
    'Magic Clock (Williams 1960)'                                                      = 'https://www.ipdb.org/machine.cgi?id=1515'
    'Magic Town (Williams 1967)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1518'
    'Magnotron (Gottlieb 1974)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1519'
    'Major League (PAMCO 1934)'                                                        = 'https://www.ipdb.org/machine.cgi?id=5497'
    'Marble Queen (Gottlieb 1953)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1541'
    'Mariner (Bally 1971)'                                                             = 'http://www.ipdb.org/machine.cgi?id=1546'
    'Mario Andretti (Gottlieb 1995)'                                                   = 'https://www.ipdb.org/machine.cgi?id=3793'
    'Mars God of War (Gottlieb 1981)'                                                  = 'http://www.ipdb.org/machine.cgi?id=1549'
    'Mars Trek (Sonic 1977)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1550'
    'Martian Queen (LTD do Brasil 1981)'                                               = 'https://www.ipdb.org/machine.cgi?id=5885'
    'Mary Shelley''s Frankenstein (Sega 1995)'                                         = 'http://www.ipdb.org/machine.cgi?id=947'
    'Mary Shelley''s Frankenstein - B&W Edition (Sega 1995)'                           = 'http://www.ipdb.org/machine.cgi?id=947'
    'Masquerade (Gottlieb 1966)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1553'
    'Mata Hari (Bally 1978)'                                                           = 'http://www.ipdb.org/machine.cgi?id=4501'
    'Maverick (Data East 1994)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1561'
    'Medieval Madness (Williams 1997)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4032'
    'Medieval Madness - B&W Edition (Williams 1997)'                                   = 'http://www.ipdb.org/machine.cgi?id=4032'
    'Medieval Madness - Remake Edition (Williams 1997)'                                = 'http://www.ipdb.org/machine.cgi?id=4032'
    'Medieval Madness - Redux Edition (Williams 1997)'                                 = 'http://www.ipdb.org/machine.cgi?id=4032'
    'Medusa (Bally 1981)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1565'
    'Melody (Gottlieb 1967)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1566'
    'Mermaid (Gottlieb 1951)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1574'
    'Merry-Go-Round (Gottlieb 1960)'                                                   = 'https://www.ipdb.org/machine.cgi?id=1578'
    'Metal Man (Inder 1992)'                                                           = 'https://www.ipdb.org/machine.cgi?id=4092'
    'Metallica (Premium Monsters) (Stern 2013)'                                        = 'https://www.ipdb.org/machine.cgi?id=6030'
    'Metallica (Premium Monsters) - Christmas Edition (Stern 2013)'                    = 'https://www.ipdb.org/machine.cgi?id=6030'
    'Metallica - Master of Puppets (Original 2020)'                                    = 'http://www.ipdb.org/machine.cgi?id=6030'
    'Meteor (Taito do Brasil 1979)'                                                    = 'http://www.ipdb.org/machine.cgi?id=4571'
    'Meteor (Stern 1979)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1580'
    'Metropolis (Maresa 1982)'                                                         = 'https://www.ipdb.org/machine.cgi?id=5732'
    'Mibs (Gottlieb 1969)'                                                             = 'http://www.ipdb.org/machine.cgi?id=1589'
    'Michael Jordan (Data East 1992)'                                                  = 'https://www.ipdb.org/machine.cgi?id=3425'
    'Michael Jordan - Black Cat Edition (Data East 1992)'                              = 'https://www.ipdb.org/machine.cgi?id=3425'
    'Middle Earth (Atari 1978)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1590'
    'Midget Hi-Ball (Peo 1932)'                                                        = 'https://www.ipdb.org/machine.cgi?id=4657'
    'Millionaire (Williams 1987)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1597'
    'Mini Cycle (Gottlieb 1970)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1604'
    'Mini Golf (Williams 1964)'                                                        = 'https://www.ipdb.org/machine.cgi?id=3434'
    'Mini Pool (Gottlieb 1969)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1605'
    'Mini-Baseball (Chicago Coin 1972)'                                                = 'https://www.ipdb.org/machine.cgi?id=5985'
    'Miss World (Geiger 1982)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3970'
    'Miss-O (Williams 1969)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1612'
    'Mississippi (Recreativos Franco 1973)'                                            = 'https://www.ipdb.org/machine.cgi?id=5955'
    'Monaco (Segasa 1977)'                                                             = 'https://www.ipdb.org/machine.cgi?id=1614'
    'Monday Night Football (Data East 1989)'                                           = 'http://www.ipdb.org/machine.cgi?id=1616'
    'Monopoly (Stern 2001)'                                                            = 'http://www.ipdb.org/machine.cgi?id=4505'
    'Monster Bash (Williams 1998)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4441'
    'Monte Carlo (Gottlieb 1987)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1622'
    'Monte Carlo (Bally 1973)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1621'
    'Moon Light (Inder 1987)'                                                          = 'http://www.ipdb.org/machine.cgi?id=4416'
    'Moon Shot (Chicago Coin 1969)'                                                    = 'https://www.ipdb.org/machine.cgi?id=1628'
    'Motordome (Bally 1986)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1633'
    'Moulin Rouge (Williams 1965)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1634'
    'Mousin'' Around! (Bally 1989)'                                                    = 'http://www.ipdb.org/machine.cgi?id=1635'
    'Mr. & Mrs. Pac-Man Pinball (Bally 1982)'                                          = 'http://www.ipdb.org/machine.cgi?id=1639'
    'Mr. Black (Taito do Brasil 1984)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4586'
    'Mr. Evil (Recel 1978)'                                                            = 'https://www.ipdb.org/machine.cgi?id=1638'
    'Mundial 90 (Inder 1990)'                                                          = 'http://www.ipdb.org/machine.cgi?id=4094'
    'Mustang (Gottlieb 1977)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1645'
    'Mustang (Limited Edition) (Stern 2014)'                                           = 'http://www.ipdb.org/machine.cgi?id=6100'
    'Mystery Castle (Alvin G. 1993)'                                                   = 'http://www.ipdb.org/machine.cgi?id=1647'
    'Mystic (Bally 1980)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1650'
    'NASCAR (Stern 2005)'                                                              = 'http://www.ipdb.org/machine.cgi?id=5093'
    'NASCAR - Dale Jr. (Stern 2005)'                                                   = 'http://www.ipdb.org/machine.cgi?id=5093'
    'NASCAR - Grand Prix (Stern 2005)'                                                 = 'http://www.ipdb.org/machine.cgi?id=5093'
    'NBA (Stern 2009)'                                                                 = 'https://www.ipdb.org/machine.cgi?id=5442'
    'NBA Fastbreak (Bally 1997)'                                                       = 'http://www.ipdb.org/machine.cgi?id=4023'
    'NBA Mac (MAC 1986)'                                                               = 'http://www.ipdb.org/machine.cgi?id=4606'
    'NFL (Stern 2001)'                                                                 = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Commanders Edition (Stern 2001)'                                            = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Ravens Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Saints Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Seahawks Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Steelers Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Giants Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Panthers Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Raiders Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Rams Edition (Stern 2001)'                                                  = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Falcons Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Eagles Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Cowboys Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Chiefs Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Chargers Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Cardinals Edition (Stern 2001)'                                             = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Buccaneers Edition (Stern 2001)'                                            = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - 49ers Edition (Stern 2001)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Bengals Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Broncos Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Browns Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Titans Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Packers Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Bears Edition (Stern 2001)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Lions Edition (Stern 2001)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Vikings Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Jets Edition (Stern 2001)'                                                  = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Patriots Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Bills Edition (Stern 2001)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Dolphins Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Jaguars Edition (Stern 2001)'                                               = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Texans Edition (Stern 2001)'                                                = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Colts Edition (Stern 2001)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4540'
    'NFL - Redskins Edition (Stern 2001)'                                              = 'http://www.ipdb.org/machine.cgi?id=4540'
    'Nags (Williams 1960)'                                                             = 'https://www.ipdb.org/machine.cgi?id=1654'
    'Nairobi (Maresa 1966)'                                                            = 'https://www.ipdb.org/machine.cgi?id=6229'
    'Nautilus (Playmatic 1984)'                                                        = 'http://www.ipdb.org/machine.cgi?id=822'
    'Nemesis (Peyper 1986)'                                                            = 'http://www.ipdb.org/machine.cgi?id=4880'
    'Neptune (Gottlieb 1978)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1662'
    'New Wave (Bell Games 1985)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3482'
    'New World (Playmatic 1976)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1672'
    'New York (Gottlieb 1976)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1673'
    'Night Moves (International Concepts 1989)'                                        = 'http://www.ipdb.org/machine.cgi?id=3507'
    'Night Rider (Bally 1977)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1677'
    'Nine Ball (Stern 1980)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1678'
    'Nip-It (Bally 1973)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1680'
    'Nitro Ground Shaker (Bally 1980)'                                                 = 'http://www.ipdb.org/machine.cgi?id=1682'
    'No Fear - Dangerous Sports (Williams 1995)'                                       = 'http://www.ipdb.org/machine.cgi?id=2852'
    'No Good Gofers (Williams 1997)'                                                   = 'http://www.ipdb.org/machine.cgi?id=4338'
    'North Pole (Playmatic 1967)'                                                      = 'https://www.ipdb.org/machine.cgi?id=6310'
    'North Star (Gottlieb 1964)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1683'
    'Now (Gottlieb 1971)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1685'
    'Nudge-It (Gottlieb 1990)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3454'
    'Nudgy (Bally 1947)'                                                               = 'https://www.ipdb.org/machine.cgi?id=1686'
    'Nugent (Stern 1978)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1687'
    'OXO (Williams 1973)'                                                              = 'http://www.ipdb.org/machine.cgi?id=1733'
    'Oba-Oba (Taito do Brasil 1979)'                                                   = 'http://www.ipdb.org/machine.cgi?id=4572'
    'Odin Deluxe (Sonic 1985)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3448'
    'Odisea Paris-Dakar (Peyper 1987)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4879'
    'Old Chicago (Bally 1976)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1704'
    'Old Coney Island! (Game Plan 1979)'                                               = 'http://www.ipdb.org/machine.cgi?id=553'
    'Olympics (Chicago Coin 1975)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1711'
    'Olympics (Gottlieb 1962)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1714'
    'Olympus (Juegos Populares 1986)'                                                  = 'https://www.ipdb.org/machine.cgi?id=5140'
    'On Beam (Bally 1969)'                                                             = 'https://www.ipdb.org/machine.cgi?id=1715'
    'Op-Pop-Pop (Bally 1969)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1722'
    'Operation Thunder (Gottlieb 1992)'                                                = 'http://www.ipdb.org/machine.cgi?id=1721'
    'Orbit (Gottlieb 1971)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1724'
    'Orbitor 1 (Stern 1982)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1725'
    'Out of Sight (Gottlieb 1974)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1727'
    'Outer Space (Gottlieb 1972)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1728'
    'PIN-BOT (Williams 1986)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1796'
    'Paddock (Williams 1969)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1735'
    'Palace Guard (Gottlieb 1968)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1737'
    'Panthera (Gottlieb 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1745'
    'Paradise (Gottlieb 1965)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1752'
    'Paragon (Bally 1979)'                                                             = 'http://www.ipdb.org/machine.cgi?id=1755'
    'Party Animal (Bally 1987)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1763'
    'Pat Hand (Williams 1975)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1767'
    'Paul Bunyan (Gottlieb 1968)'                                                      = 'http://www.ipdb.org/machine.cgi?id=1768'
    'Pennant Fever (Williams 1984)'                                                    = 'http://www.ipdb.org/machine.cgi?id=3335'
    'Petaco (Juegos Populares 1984)'                                                   = 'https://www.ipdb.org/machine.cgi?id=4883'
    'Petaco 2 (Juegos Populares 1985)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5257'
    'Phantom Haus (Williams 1996)'                                                     = 'https://www.ipdb.org/machine.cgi?id=6840'
    'Phantom of the Opera (Data East 1990)'                                            = 'http://www.ipdb.org/machine.cgi?id=1777'
    'Pharaoh (Williams 1981)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1778'
    'Pharaoh - Dead Rise (Original 2019)'                                              = 'http://www.ipdb.org/machine.cgi?id=1778'
    'Phase II (J. Esteban 1975)'                                                       = 'https://www.ipdb.org/machine.cgi?id=5787'
    'Phoenix (Williams 1978)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1780'
    'Pin-Up (Gottlieb 1975)'                                                           = 'http://www.ipdb.org/machine.cgi?id=1789'
    'Pinball (EM) (Stern 1977)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1792'
    'Pinball (SS) (Stern 1977)'                                                        = 'https://www.ipdb.org/machine.cgi?id=4694'
    'Pinball Action (Tekhan 1985)'                                                     = 'https://www.ipdb.org/machine.cgi?id=5252'
    'Pinball Champ ''82 (Zaccaria 1982)'                                               = 'http://www.ipdb.org/machine.cgi?id=1794'
    'Pinball Lizard (Game Plan 1980)'                                                  = 'https://www.ipdb.org/machine.cgi?id=1464'
    'Pinball Magic (Capcom 1995)'                                                      = 'http://www.ipdb.org/machine.cgi?id=3596'
    'Pinball Pool (Gottlieb 1979)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1795'
    'Pinball Squared (Gottlieb 1984)'                                                  = 'https://www.ipdb.org/machine.cgi?id=5341'
    'Pink Panther (Gottlieb 1981)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1800'
    'Pioneer (Gottlieb 1976)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1802'
    'Pipeline (Gottlieb 1981)'                                                         = 'https://www.ipdb.org/machine.cgi?id=5327'
    'Pirate Gold (Chicago Coin 1969)'                                                  = 'https://www.ipdb.org/machine.cgi?id=1804'
    'Pirates of the Caribbean (Stern 2006)'                                            = 'http://www.ipdb.org/machine.cgi?id=5163'
    'Pistol Poker (Alvin G. 1993)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1805'
    'Pit Stop (Williams 1968)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1806'
    'Planets (Williams 1971)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1811'
    'Play Pool (Gottlieb 1972)'                                                        = 'https://www.ipdb.org/machine.cgi?id=1819'
    'PlayMates (Gottlieb 1968)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1828'
    'Playball (Gottlieb 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1816'
    'Playboy - Definitive Edition (Bally 1978)'                                        = 'http://www.ipdb.org/machine.cgi?id=1823'
    'Playboy (Bally 1978)'                                                             = 'http://www.ipdb.org/machine.cgi?id=1823'
    'Playboy 35th Anniversary (Data East 1989)'                                        = 'https://www.ipdb.org/machine.cgi?id=1822'
    'Pokerino (Williams 1978)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1839'
    'Polar Explorer (Taito do Brasil 1983)'                                            = 'http://www.ipdb.org/machine.cgi?id=4588'
    'Pole Position (Sonic 1987)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3322'
    'Police Force (Williams 1989)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1841'
    'Polo (Gottlieb 1970)'                                                             = 'https://www.ipdb.org/machine.cgi?id=1843'
    'Pool Sharks (Bally 1990)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1848'
    'Pop-A-Card (Gottlieb 1972)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1849'
    'Popeye Saves the Earth (Bally 1994)'                                              = 'http://www.ipdb.org/machine.cgi?id=1851'
    'Poseidon (Gottlieb 1978)'                                                         = 'https://www.ipdb.org/machine.cgi?id=1852'
    'Post Time (Williams 1969)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1853'
    'Primus (Stern 2018)'                                                              = 'https://www.ipdb.org/machine.cgi?id=6610'
    'Pro Pool (Gottlieb 1973)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1866'
    'Pro-Football (Gottlieb 1973)'                                                     = 'https://www.ipdb.org/machine.cgi?id=1865'
    'Prospector (Sonic 1977)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1871'
    'Psychedelic (Gottlieb 1970)'                                                      = 'https://www.ipdb.org/machine.cgi?id=1873'
    'Punchy the Clown (Alvin G. 1993)'                                                 = 'https://www.ipdb.org/machine.cgi?id=3508'
    'Punk! (Gottlieb 1982)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1877'
    'Pyramid (Gottlieb 1978)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1881'
    'Queen of Hearts (Gottlieb 1952)'                                                  = 'https://www.ipdb.org/machine.cgi?id=1891'
    'Quick Draw (Gottlieb 1975)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1893'
    'Quicksilver (Stern 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1895'
    'Rack ''Em Up! (Gottlieb 1983)'                                                    = 'http://www.ipdb.org/machine.cgi?id=1902'
    'Rack-A-Ball (Gottlieb 1962)'                                                      = 'https://www.ipdb.org/machine.cgi?id=1903'
    'Radical! (Bally 1990)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1904'
    'Radical! (prototype) (Bally 1990)'                                                = 'https://www.ipdb.org/machine.cgi?id=1904'
    'Rainbow (Gottlieb 1956)'                                                          = 'https://www.ipdb.org/machine.cgi?id=1911'
    'Rally (Taito do Brasil 1980)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4581'
    'Rambo (Original 2019)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1922'
    'Rancho (Williams 1976)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1918'
    'Rancho (Gottlieb 1966)'                                                           = 'https://www.ipdb.org/machine.cgi?id=1917'
    'Rapid Fire (Bally 1982)'                                                          = 'http://www.ipdb.org/machine.cgi?id=3568'
    'Raven (Gottlieb 1986)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1922'
    'Rawhide (Stern 1977)'                                                             = 'https://www.ipdb.org/machine.cgi?id=3545'
    'Ready...Aim...Fire! (Gottlieb 1983)'                                              = 'http://www.ipdb.org/machine.cgi?id=1924'
    'Red & Ted''s Road Show (Williams 1994)'                                           = 'http://www.ipdb.org/machine.cgi?id=1972'
    'Red Baron (Chicago Coin 1975)'                                                    = 'https://www.ipdb.org/machine.cgi?id=1933'
    'Rescue 911 (Gottlieb 1994)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1951'
    'Rey de Diamantes (Petaco 1967)'                                                   = 'https://www.ipdb.org/machine.cgi?id=4368'
    'Rider''s Surf (Jocmatic 1986)'                                                    = 'https://www.ipdb.org/machine.cgi?id=4102'
    'Ripley''s Believe it or Not! (Stern 2004)'                                        = 'http://www.ipdb.org/machine.cgi?id=4917'
    'Riverboat Gambler (Williams 1990)'                                                = 'http://www.ipdb.org/machine.cgi?id=1966'
    'Ro Go (Bally 1974)'                                                               = 'http://www.ipdb.org/machine.cgi?id=1969'
    'Road Kings (Williams 1986)'                                                       = 'http://www.ipdb.org/machine.cgi?id=1970'
    'Road Race (Gottlieb 1969)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1971'
    'Road Runner (Atari 1979)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3517'
    'Robo-War (Gottlieb 1988)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1975'
    'Robocop (Data East 1989)'                                                         = 'http://www.ipdb.org/machine.cgi?id=1976'
    'Robot (Zaccaria 1985)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1977'
    'Rock (Gottlieb 1985)'                                                             = 'http://www.ipdb.org/machine.cgi?id=1978'
    'Rock 2500 (Playmatic 1985)'                                                       = 'https://www.ipdb.org/machine.cgi?id=3538'
    'Rock Encore (Gottlieb 1986)'                                                      = 'https://www.ipdb.org/machine.cgi?id=1979'
    'Rock Star (Gottlieb 1978)'                                                        = 'http://www.ipdb.org/machine.cgi?id=1983'
    'RockMakers (Bally 1968)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1980'
    'Rocket III (Bally 1967)'                                                          = 'http://www.ipdb.org/machine.cgi?id=1989'
    'Rocky (Gottlieb 1982)'                                                            = 'http://www.ipdb.org/machine.cgi?id=1993'
    'Roller Coaster (Gottlieb 1971)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2002'
    'Roller Derby (Bally 1960)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2003'
    'Roller Disco (Gottlieb 1980)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2005'
    'RollerCoaster Tycoon (Stern 2002)'                                                = 'http://www.ipdb.org/machine.cgi?id=4536'
    'Rollergames (Williams 1990)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2006'
    'Rollet (Barok Co 1931)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2007'
    'Rolling Stones (Bally 1980)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2010'
    'Rolling Stones - B&W Edition (Bally 1980)'                                        = 'http://www.ipdb.org/machine.cgi?id=2010'
    'Roman Victory (Taito do Brasil 1977)'                                             = 'https://www.ipdb.org/machine.cgi?id=5493'
    'Royal Flush (Gottlieb 1976)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2035'
    'Royal Flush Deluxe (Gottlieb 1983)'                                               = 'http://www.ipdb.org/machine.cgi?id=2036'
    'Royal Guard (Gottlieb 1968)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2037'
    'Royal Pair (Gottlieb 1974)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2038'
    'Royal Pair - 2 Pop Bumper Edition (Gottlieb 1974)'                                = 'https://www.ipdb.org/machine.cgi?id=2038'
    'Running Horse (Inder 1976)'                                                       = 'https://www.ipdb.org/machine.cgi?id=4414'
    'Safe Cracker (Bally 1996)'                                                        = 'http://www.ipdb.org/machine.cgi?id=3782'
    'San Francisco (Williams 1964)'                                                    = 'https://www.ipdb.org/machine.cgi?id=2049'
    'Satin Doll (Williams 1975)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2057'
    'Scared Stiff (Bally 1996)'                                                        = 'http://www.ipdb.org/machine.cgi?id=3915'
    'Schuss (Rally 1968)'                                                              = 'https://www.ipdb.org/machine.cgi?id=3541'
    'Scorpion (Williams 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2067'
    'Scram! (Hutchison 1932)'                                                          = 'https://www.ipdb.org/machine.cgi?id=5138'
    'Scramble (Tecnoplay 1987)'                                                        = 'https://www.ipdb.org/machine.cgi?id=3557'
    'Scuba (Gottlieb 1970)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2077'
    'Sea Jockeys (Williams 1951)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2084'
    'Sea Ray (Bally 1971)'                                                             = 'http://www.ipdb.org/machine.cgi?id=2085'
    'Seawitch (Stern 1980)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2089'
    'Secret Service (Data East 1988)'                                                  = 'http://www.ipdb.org/machine.cgi?id=2090'
    'Seven Winner (Inder 1973)'                                                        = 'https://www.ipdb.org/machine.cgi?id=4407'
    'Sexy Girl (Arkon 1980)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2106'
    'Sexy Girl - Nude Edition (Arkon 1980)'                                            = 'http://www.ipdb.org/machine.cgi?id=2106'
    'Shamrock (Inder 1977)'                                                            = 'https://www.ipdb.org/machine.cgi?id=5717'
    'Shangri-La (Williams 1967)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2110'
    'Shaq Attaq (Gottlieb 1995)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2874'
    'Shark (Taito do Brasil 1982)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4582'
    'Sharkey''s Shootout (Stern 2000)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4492'
    'Sharp Shooter II (Game Plan 1983)'                                                = 'http://www.ipdb.org/machine.cgi?id=2114'
    'Sharpshooter (Game Plan 1979)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2113'
    'Sheriff (Gottlieb 1971)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2116'
    'Sherokee (Rowamet 1978)'                                                          = 'https://www.ipdb.org/machine.cgi?id=6707'
    'Ship Ahoy (Gottlieb 1976)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2119'
    'Ship-Mates (Gottlieb 1964)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2120'
    'Shock (Taito do Brasil 1979)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4573'
    'Shooting Star (Junior) (Daval 1934)'                                              = 'https://www.ipdb.org/machine.cgi?id=6021'
    'Shooting the Rapids (Zaccaria 1979)'                                              = 'https://www.ipdb.org/machine.cgi?id=3606'
    'Shrek (Stern 2008)'                                                               = 'http://www.ipdb.org/machine.cgi?id=5301'
    'Silver Cup (Genco 1933)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2146'
    'Silver Slugger (Gottlieb 1990)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2152'
    'Silverball Mania (Bally 1980)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2156'
    'Sinbad (Gottlieb 1978)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2159'
    'Sing Along (Gottlieb 1967)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2160'
    'Sir Lancelot (Peyper 1994)'                                                       = 'http://www.ipdb.org/machine.cgi?id=4949'
    'Sittin'' Pretty (Gottlieb 1958)'                                                  = 'https://www.ipdb.org/machine.cgi?id=2164'
    'Skateball (Bally 1980)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2170'
    'Skateboard (Inder 1980)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4479'
    'Skipper (Gottlieb 1969)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2189'
    'Sky Jump (Gottlieb 1974)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2195'
    'Sky Kings (Bally 1974)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2196'
    'Sky Ride (Genco 1933)'                                                            = 'https://www.ipdb.org/machine.cgi?id=2200'
    'Sky-Line (Gottlieb 1965)'                                                         = 'https://www.ipdb.org/machine.cgi?id=3240'
    'Skylab (Williams 1974)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2202'
    'Skyrocket (Bally 1971)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2204'
    'Skyscraper (Bally 1934)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2205'
    'Skyway (Williams 1954)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2206'
    'Sleic Pin-BALL (Sleic 1994)'                                                      = 'https://www.ipdb.org/machine.cgi?id=4620'
    'Sleic Pin-BALL - Cabinet Edition (Sleic 1994)'                                    = 'https://www.ipdb.org/machine.cgi?id=4620'
    'Sleic Pin-BALL - Desktop Edition (Sleic 1994)'                                    = 'https://www.ipdb.org/machine.cgi?id=4620'
    'Slick Chick (Gottlieb 1963)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2208'
    'Smart Set (Williams 1969)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2215'
    'Snake Machine (Taito do Brasil 1982)'                                             = 'http://www.ipdb.org/machine.cgi?id=4585'
    'Snooker (Gottlieb 1985)'                                                          = 'https://www.ipdb.org/machine.cgi?id=5343'
    'Snow Derby (Gottlieb 1970)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2229'
    'Snow Queen (Gottlieb 1970)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2230'
    'Soccer (Gottlieb 1975)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2233'
    'Soccer (Williams 1964)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2232'
    'Soccer Kings (Zaccaria 1982)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2235'
    'Solar City (Gottlieb 1977)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2237'
    'Solar Fire (Williams 1981)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2238'
    'Solar Ride (Electromatic 1982)'                                                   = 'https://www.ipdb.org/machine.cgi?id=5696'
    'Solar Ride (Gottlieb 1979)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2239'
    'Solar Wars (Sonic 1986)'                                                          = 'https://www.ipdb.org/machine.cgi?id=3273'
    'Solids N Stripes (Williams 1971)'                                                 = 'http://www.ipdb.org/machine.cgi?id=2240'
    'Solitaire (Gottlieb 1967)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2241'
    'Sorcerer (Williams 1985)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2242'
    'Sound Stage (Chicago Coin 1976)'                                                  = 'https://www.ipdb.org/machine.cgi?id=2243'
    'South Park (Sega 1999)'                                                           = 'http://www.ipdb.org/machine.cgi?id=4444'
    'Space Gambler (Playmatic 1978)'                                                   = 'https://www.ipdb.org/machine.cgi?id=2250'
    'Space Invaders (Bally 1980)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2252'
    'Space Mission (Williams 1976)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2253'
    'Space Odyssey (Williams 1976)'                                                    = 'https://www.ipdb.org/machine.cgi?id=2254'
    'Space Orbit (Gottlieb 1972)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2255'
    'Space Patrol (Taito do Brasil 1978)'                                              = 'https://www.ipdb.org/machine.cgi?id=6582'
    'Space Poker (LTD do Brasil 1982)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5886'
    'Space Rider (Geiger 1980)'                                                        = 'https://www.ipdb.org/machine.cgi?id=4018'
    'Space Riders (Atari 1978)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2258'
    'Space Shuttle (Taito do Brasil 1985)'                                             = 'https://www.ipdb.org/machine.cgi?id=4583'
    'Space Shuttle (Williams 1984)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2260'
    'Space Station (Williams 1987)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2261'
    'Space Time (Bally 1972)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2262'
    'Space Train (MAC 1987)'                                                           = 'http://www.ipdb.org/machine.cgi?id=3895'
    'Space Walk (Gottlieb 1979)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2263'
    'Spanish Eyes (Williams 1972)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2265'
    'Spark Plugs (Williams 1951)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2267'
    'Speakeasy (Playmatic 1977)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2269'
    'Speakeasy (Bally 1982)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2270'
    'Speakeasy 4 (Bally 1982)'                                                         = 'http://www.ipdb.org/machine.cgi?id=4342'
    'Special Force (Bally 1986)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2272'
    'Spectrum (Bally 1982)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2274'
    'Speed Test (Taito do Brasil 1982)'                                                = 'http://www.ipdb.org/machine.cgi?id=4589'
    'Spider-Man (Stern 2007)'                                                          = 'http://www.ipdb.org/machine.cgi?id=5237'
    'Spider-Man - Classic Edition (Stern 2007)'                                        = 'http://www.ipdb.org/machine.cgi?id=5237'
    'Spider-Man (Black Suited) (Stern 2007)'                                           = 'https://www.ipdb.org/machine.cgi?id=5650'
    'Spider-Man (Vault Edition) (Stern 2016)'                                          = 'https://www.ipdb.org/machine.cgi?id=6328'
    'Spider-Man (Vault Edition) - Classic Edition (Stern 2016)'                        = 'https://www.ipdb.org/machine.cgi?id=6328'
    'Spin Out (Gottlieb 1975)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2286'
    'Spin Wheel (Gottlieb 1968)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2287'
    'Spin-A-Card (Gottlieb 1969)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2288'
    'Spinning Wheel (Automaticos 1970)'                                                = 'https://www.ipdb.org/machine.cgi?id=6402'
    'Spirit (Gottlieb 1982)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2292'
    'Spirit of 76 (Gottlieb 1975)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2293'
    'Split Second (Stern 1981)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2297'
    'Spot Pool (Gottlieb 1976)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2316'
    'Spot a Card (Gottlieb 1960)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2318'
    'Spring Break (Gottlieb 1987)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2324'
    'Spy Hunter (Bally 1984)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2328'
    'Stampede (Stern 1977)'                                                            = 'https://www.ipdb.org/machine.cgi?id=5232'
    'Star Action (Williams 1973)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2342'
    'Star Fire (Playmatic 1985)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3453'
    'Star Gazer (Stern 1980)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2346'
    'Star God (Zaccaria 1980)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3458'
    'Star Light (Williams 1984)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2362'
    'Star Pool (Williams 1974)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2352'
    'Star Race (Gottlieb 1980)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2353'
    'Star Ship (Bally 1976)'                                                           = 'https://www.ipdb.org/machine.cgi?id=3498'
    'Star Trek (Data East 1991)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2356'
    'Star Trek (Gottlieb 1971)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2354'
    'Star Trek (Bally 1979)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2355'
    'Star Trek - Mirror Universe Edition (Bally 1979)'                                 = 'http://www.ipdb.org/machine.cgi?id=2355'
    'Star Trek (Enterprise Limited Edition) (Stern 2013)'                              = 'http://www.ipdb.org/machine.cgi?id=6046'
    'Star Trek - The Next Generation (Williams 1993)'                                  = 'http://www.ipdb.org/machine.cgi?id=2357'
    'Star Trip (Game Plan 1979)'                                                       = 'https://www.ipdb.org/machine.cgi?id=3605'
    'Star Wars (Data East 1992)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2358'
    'Star Wars (Sonic 1987)'                                                           = 'http://www.ipdb.org/machine.cgi?id=4513'
    'Star Wars - The Empire Strikes Back (Hankin 1980)'                                = 'http://www.ipdb.org/machine.cgi?id=2868'
    'Star Wars Trilogy Special Edition (Sega 1997)'                                    = 'http://www.ipdb.org/machine.cgi?id=4054'
    'Star-Jet (Bally 1963)'                                                            = 'https://www.ipdb.org/machine.cgi?id=2347'
    'Stardust (Williams 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2359'
    'Stargate (Gottlieb 1995)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2847'
    'Stars (Stern 1978)'                                                               = 'http://www.ipdb.org/machine.cgi?id=2366'
    'Starship Troopers (Sega 1997)'                                                    = 'http://www.ipdb.org/machine.cgi?id=4341'
    'Starship Troopers - VPN Edition (Sega 1997)'                                      = 'http://www.ipdb.org/machine.cgi?id=4341'
    'Stellar Airship (Geiger 1979)'                                                    = 'http://www.ipdb.org/machine.cgi?id=4016'
    'Stellar Wars (Williams 1979)'                                                     = 'https://www.ipdb.org/machine.cgi?id=2372'
    'Still Crazy (Williams 1984)'                                                      = 'https://www.ipdb.org/machine.cgi?id=3730'
    'Stingray (Stern 1977)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2377'
    'Stock Car (Gottlieb 1970)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2378'
    'Straight Flush (Williams 1970)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2393'
    'Strange Science (Bally 1986)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2396'
    'Strange World (Gottlieb 1978)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2397'
    'Strato-Flite (Williams 1974)'                                                     = 'https://www.ipdb.org/machine.cgi?id=2398'
    'Street Fighter II (Gottlieb 1993)'                                                = 'http://www.ipdb.org/machine.cgi?id=2403'
    'Strike (Zaccaria 1978)'                                                           = 'https://www.ipdb.org/machine.cgi?id=3363'
    'Striker (Gottlieb 1982)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2405'
    'Striker Xtreme (Stern 2000)'                                                      = 'http://www.ipdb.org/machine.cgi?id=4459'
    'Strikes N'' Spares (Gottlieb 1995)'                                               = 'http://www.ipdb.org/machine.cgi?id=4336'
    'Strikes and Spares (Bally 1978)'                                                  = 'http://www.ipdb.org/machine.cgi?id=2406'
    'Strip Joker Poker (Gottlieb 1978)'                                                = 'https://www.ipdb.org/machine.cgi?id=1306'
    'Stripping Funny (Inder 1974)'                                                     = 'https://www.ipdb.org/machine.cgi?id=4410'
    'Student Prince (Williams 1968)'                                                   = 'https://www.ipdb.org/machine.cgi?id=2408'
    'Sultan (Taito do Brasil 1979)'                                                    = 'https://www.ipdb.org/machine.cgi?id=5009'
    'Summer Time (Williams 1972)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2415'
    'Super Bowl (Bell Games 1984)'                                                     = 'http://www.ipdb.org/machine.cgi?id=3399'
    'Super Mario Bros. (Gottlieb 1992)'                                                = 'http://www.ipdb.org/machine.cgi?id=2435'
    'Super Mario Bros. Mushroom World (Gottlieb 1992)'                                 = 'http://www.ipdb.org/machine.cgi?id=3427'
    'Super Nova (Game Plan 1980)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2436'
    'Super Orbit (Gottlieb 1983)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2437'
    'Super Score (Gottlieb 1967)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2441'
    'Super Soccer (Gottlieb 1975)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2443'
    'Super Spin (Gottlieb 1977)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2445'
    'Super Star (Williams 1972)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2446'
    'Super Star (Chicago Coin 1975)'                                                   = 'https://www.ipdb.org/machine.cgi?id=2447'
    'Super Straight (Sonic 1977)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2449'
    'Super-Flite (Williams 1974)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2452'
    'Superman (Atari 1979)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2454'
    'Supersonic (Bally 1979)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2455'
    'Sure Shot (Taito do Brasil 1981)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4574'
    'Sure Shot (Gottlieb 1976)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2457'
    'Surf ''n Safari (Gottlieb 1991)'                                                  = 'http://www.ipdb.org/machine.cgi?id=2461'
    'Surf Champ (Gottlieb 1976)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2459'
    'Surf Side (Gottlieb 1967)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2464'
    'Surfer (Gottlieb 1976)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2465'
    'Sweet Hearts (Gottlieb 1963)'                                                     = 'https://www.ipdb.org/machine.cgi?id=2474'
    'Sweet Sioux (Gottlieb 1959)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2475'
    'Swing-Along (Gottlieb 1963)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2484'
    'Swinger (Williams 1972)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2485'
    'Swords of Fury (Williams 1988)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2486'
    'T.K.O. (Gottlieb 1979)'                                                           = 'http://www.ipdb.org/machine.cgi?id=4599'
    'TRON Classic - PuP-Pack Edition (Original 2018)'                                  = 'http://www.ipdb.org/machine.cgi?id=1745'
    'TRON Classic (Original 2018)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1745'
    'TX-Sector (Gottlieb 1988)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2699'
    'Tag-Team Pinball (Gottlieb 1985)'                                                 = 'http://www.ipdb.org/machine.cgi?id=2489'
    'Tales from the Crypt (Data East 1993)'                                            = 'http://www.ipdb.org/machine.cgi?id=2493'
    'Tales of the Arabian Nights (Williams 1996)'                                      = 'http://www.ipdb.org/machine.cgi?id=3824'
    'Tam-Tam (Playmatic 1975)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2496'
    'Target Alpha (Gottlieb 1976)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2500'
    'Target Pool (Gottlieb 1969)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2502'
    'Taxi - Lola Edition (Williams 1988)'                                              = 'http://www.ipdb.org/machine.cgi?id=2505'
    'Taxi (Williams 1988)'                                                             = 'http://www.ipdb.org/machine.cgi?id=2505'
    'Teacher''s Pet (Williams 1965)'                                                   = 'https://www.ipdb.org/machine.cgi?id=2506'
    'Team One (Gottlieb 1977)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2507'
    'Tee''d Off (Gottlieb 1993)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2508'
    'Teenage Mutant Ninja Turtles (Data East 1991)'                                    = 'http://www.ipdb.org/machine.cgi?id=2509'
    'Teenage Mutant Ninja Turtles - PuP-Pack Edition (Data East 1991)'                 = 'http://www.ipdb.org/machine.cgi?id=2509'
    'Ten Stars (Zaccaria 1976)'                                                        = 'https://www.ipdb.org/machine.cgi?id=3373'
    'Terminator 2 - Judgment Day (Williams 1991)'                                      = 'http://www.ipdb.org/machine.cgi?id=2524'
    'Terminator 2 - Judgment Day - Chrome Edition (Williams 1991)'                     = 'http://www.ipdb.org/machine.cgi?id=2524'
    'Terminator 3 - Rise of the Machines (Stern 2003)'                                 = 'http://www.ipdb.org/machine.cgi?id=4787'
    'Terrific Lake (Sport matic 1987)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5289'
    'Texas Ranger (Gottlieb 1972)'                                                     = 'https://www.ipdb.org/machine.cgi?id=2527'
    'Addams Family, The (Bally 1992)'                                                  = 'http://www.ipdb.org/machine.cgi?id=20'
    'Addams Family, The - B&W Edition (Bally 1992)'                                    = 'http://www.ipdb.org/machine.cgi?id=20'
    'Amazing Spider-Man, The - Sinister Six Edition (Gottlieb 1980)'                   = 'http://www.ipdb.org/machine.cgi?id=2285'
    'Amazing Spider-Man, The (Gottlieb 1980)'                                          = 'http://www.ipdb.org/machine.cgi?id=2285'
    'Atarians, The (Atari 1976)'                                                       = 'https://www.ipdb.org/machine.cgi?id=102'
    'Avengers (Pro), The (Stern 2012)'                                                 = 'http://www.ipdb.org/machine.cgi?id=5938'
    'Bally Game Show, The (Bally 1990)'                                                = 'http://www.ipdb.org/machine.cgi?id=985'
    'Champion Pub, The (Bally 1998)'                                                   = 'http://www.ipdb.org/machine.cgi?id=4358'
    'Clash, The (Original 2018)'                                                       = 'https://www.ipdb.org/machine.cgi?id=1979'
    'Flash, The (Original 2018)'                                                       = 'http://www.ipdb.org/machine.cgi?id=871'
    'Flintstones, The - The Cartoon VR Edition (Williams 1994)'                        = 'http://www.ipdb.org/machine.cgi?id=888'
    'Flintstones, The - VR Cartoon Edition (Williams 1994)'                            = 'http://www.ipdb.org/machine.cgi?id=888'
    'Flintstones, The (Williams 1994)'                                                 = 'http://www.ipdb.org/machine.cgi?id=888'
    'Flintstones, The - Yabba Dabba Re-Doo Edition (Williams 1994)'                    = 'http://www.ipdb.org/machine.cgi?id=888'
    'Flintstones, The - Cartoon Edition (Williams 1994)'                               = 'http://www.ipdb.org/machine.cgi?id=888'
    'Games, The (Gottlieb 1984)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3391'
    'Games I, The (Gottlieb 1983)'                                                     = 'https://www.ipdb.org/machine.cgi?id=5340'
    'Getaway - High Speed II, The (Williams 1992)'                                     = 'http://www.ipdb.org/machine.cgi?id=1000'
    'Incredible Hulk, The (Gottlieb 1979)'                                             = 'http://www.ipdb.org/machine.cgi?id=1266'
    'Lord of the Rings, The - Valinor Edition (Stern 2003)'                            = 'http://www.ipdb.org/machine.cgi?id=4858'
    'Lord of the Rings, The (Stern 2003)'                                              = 'http://www.ipdb.org/machine.cgi?id=4858'
    'Lost World Jurassic Park, The (Sega 1997)'                                        = 'https://www.ipdb.org/machine.cgi?id=4136'
    'Machine - Bride of Pin-bot, The (Williams 1991)'                                  = 'http://www.ipdb.org/machine.cgi?id=1502'
    'Maple Leaf, The (Automatic 1932)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5321'
    'Moon Walking Dead, The (Original 2017)'                                           = 'http://www.ipdb.org/machine.cgi?id=6156'
    'Pabst Can Crusher, The (Stern 2016)'                                              = 'http://www.ipdb.org/machine.cgi?id=6335'
    'Party Zone, The (Bally 1991)'                                                     = 'http://www.ipdb.org/machine.cgi?id=1764'
    'Raid, The (Playmatic 1984)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3511'
    'Rolling Stones, The (Stern 2011)'                                                 = 'http://www.ipdb.org/machine.cgi?id=5668'
    'Shadow, The (Bally 1994)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2528'
    'Simpsons, The (Data East 1990)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2158'
    'Simpsons Pinball Party, The (Stern 2003)'                                         = 'http://www.ipdb.org/machine.cgi?id=4674'
    'Simpsons Treehouse of Horror, The (Original 2020)'                                = 'http://www.ipdb.org/machine.cgi?id=4674'
    'Simpsons Treehouse of Horror, The - Starlion Edition (Original 2020)'             = 'http://www.ipdb.org/machine.cgi?id=4674'
    'Six Million Dollar Man, The (Bally 1978)'                                         = 'http://www.ipdb.org/machine.cgi?id=2165'
    'Sopranos, The (Stern 2005)'                                                       = 'http://www.ipdb.org/machine.cgi?id=5053'
    'Walking Dead (Limited Edition), The (Stern 2014)'                                 = 'http://www.ipdb.org/machine.cgi?id=6156'
    'Walking Dead (Pro), The (Stern 2014)'                                             = 'https://www.ipdb.org/machine.cgi?id=6155'
    'Who''s Tommy Pinball Wizard, The (Data East 1994)'                                = 'http://www.ipdb.org/machine.cgi?id=2579'
    'Wiggler, The (Bally 1967)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2777'
    'X Files, The (Sega 1997)'                                                         = 'http://www.ipdb.org/machine.cgi?id=4137'
    'Theatre of Magic (Bally 1995)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2845'
    'Thunder Man (Apple Time 1987)'                                                    = 'https://www.ipdb.org/machine.cgi?id=4666'
    'Thunderbirds - Are Go! (Original 2022)'                                           = 'https://www.ipdb.org/machine.cgi?id=6617'
    'Thunderbirds (Original 2022)'                                                     = 'https://www.ipdb.org/machine.cgi?id=6617'
    'Ticket Tac Toe (Williams 1996)'                                                   = 'https://www.ipdb.org/machine.cgi?id=4334'
    'Tidal Wave (Gottlieb 1981)'                                                       = 'https://www.ipdb.org/machine.cgi?id=5326'
    'Tiger (Gottlieb 1975)'                                                            = 'https://www.ipdb.org/machine.cgi?id=2560'
    'Time Fantasy (Williams 1983)'                                                     = 'http://www.ipdb.org/machine.cgi?id=2563'
    'Time Line (Gottlieb 1980)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2564'
    'Time Machine (Data East 1988)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2565'
    'Time Machine (LTD do Brasil 1984)'                                                = 'https://www.ipdb.org/machine.cgi?id=5887'
    'Time Machine (Zaccaria 1983)'                                                     = 'https://www.ipdb.org/machine.cgi?id=3494'
    'Time Tunnel (Bally 1971)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2566'
    'Time Warp (Williams 1979)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2568'
    'Tiro''s (Maresa 1969)'                                                            = 'https://www.ipdb.org/machine.cgi?id=5818'
    'Titan (Taito do Brasil 1981)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4587'
    'Titan (Gottlieb 1982)'                                                            = 'https://www.ipdb.org/machine.cgi?id=5330'
    'Title Fight (Gottlieb 1990)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2573'
    'Toledo (Williams 1975)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2577'
    'Top Card (Gottlieb 1974)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2580'
    'Top Hand (Gottlieb 1973)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2582'
    'Top Score (Gottlieb 1975)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2589'
    'Topaz (Inder 1979)'                                                               = 'https://www.ipdb.org/machine.cgi?id=4477'
    'Torch (Gottlieb 1980)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2595'
    'Torpedo Alley (Data East 1988)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2603'
    'Torpedo!! (Petaco 1976)'                                                          = 'https://www.ipdb.org/machine.cgi?id=4371'
    'Total Nuclear Annihilation (Spooky Pinball 2017)'                                 = 'https://www.ipdb.org/machine.cgi?id=6444'
    'Total Nuclear Annihilation - Welcome to the Future Edition (Spooky Pinball 2017)' = 'https://www.ipdb.org/machine.cgi?id=6444'
    'Totem (Gottlieb 1979)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2607'
    'Touchdown (Williams 1967)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2609'
    'Touchdown (Gottlieb 1984)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2610'
    'Trade Winds (Williams 1962)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2621'
    'Trailer (Playmatic 1985)'                                                         = 'http://www.ipdb.org/machine.cgi?id=3276'
    'Tramway (Williams 1973)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2627'
    'Transformers (Pro) (Stern 2011)'                                                  = 'http://www.ipdb.org/machine.cgi?id=5709'
    'Transporter the Rescue (Bally 1989)'                                              = 'http://www.ipdb.org/machine.cgi?id=2630'
    'Travel Time (Williams 1972)'                                                      = 'https://www.ipdb.org/machine.cgi?id=2636'
    'Tri Zone (Williams 1979)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2641'
    'Trick Shooter (LTD do Brasil 1980)'                                               = 'https://www.ipdb.org/machine.cgi?id=5888'
    'Trident (Stern 1979)'                                                             = 'http://www.ipdb.org/machine.cgi?id=2644'
    'Triple Action (Williams 1973)'                                                    = 'https://www.ipdb.org/machine.cgi?id=2648'
    'Triple Strike (Williams 1975)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2652'
    'Triple X (Williams 1973)'                                                         = 'https://www.ipdb.org/machine.cgi?id=6497'
    'Tropic Fun (Williams 1973)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2660'
    'Truck Stop (Bally 1988)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2667'
    'Twilight Zone - B&W Edition (Bally 1993)'                                         = 'http://www.ipdb.org/machine.cgi?id=2684'
    'Twilight Zone (Bally 1993)'                                                       = 'http://www.ipdb.org/machine.cgi?id=2684'
    'Twinky (Chicago Coin 1967)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2692'
    'Twister (Sega 1996)'                                                              = 'http://www.ipdb.org/machine.cgi?id=3976'
    'Tyrannosaurus (Gottlieb 1985)'                                                    = 'https://www.ipdb.org/machine.cgi?id=5344'
    'U-Boat 65 (Nuova Bell Games 1988)'                                                = 'http://www.ipdb.org/machine.cgi?id=3736'
    'Underwater (Recel 1976)'                                                          = 'https://www.ipdb.org/machine.cgi?id=2702'
    'Universe (Gottlieb 1959)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2705'
    'Universe (Zaccaria 1976)'                                                         = 'https://www.ipdb.org/machine.cgi?id=2706'
    'V.1 (IDSA 1986)'                                                                  = 'http://www.ipdb.org/machine.cgi?id=5022'
    'Vampire (Bally 1971)'                                                             = 'https://www.ipdb.org/machine.cgi?id=2716'
    'Vector (Bally 1982)'                                                              = 'http://www.ipdb.org/machine.cgi?id=2723'
    'Vegas (Taito do Brasil 1980)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4575'
    'Vegas (Gottlieb 1990)'                                                            = 'http://www.ipdb.org/machine.cgi?id=2724'
    'Verne''s World (Spinball S.A.L. 1996)'                                            = 'http://www.ipdb.org/machine.cgi?id=4619'
    'Victory (Gottlieb 1987)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2733'
    'Viking (Bally 1980)'                                                              = 'http://www.ipdb.org/machine.cgi?id=2737'
    'Viking King (LTD do Brasil 1979)'                                                 = 'https://www.ipdb.org/machine.cgi?id=5895'
    'Viper (Stern 1981)'                                                               = 'http://www.ipdb.org/machine.cgi?id=2739'
    'Viper Night Drivin'' (Sega 1998)'                                                 = 'http://www.ipdb.org/machine.cgi?id=4359'
    'Volcano (Gottlieb 1981)'                                                          = 'http://www.ipdb.org/machine.cgi?id=2742'
    'Volley (Taito do Brasil 1981)'                                                    = 'https://www.ipdb.org/machine.cgi?id=5494'
    'Volley (Gottlieb 1976)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2743'
    'Voltan Escapes Cosmic Doom (Bally 1979)'                                          = 'http://www.ipdb.org/machine.cgi?id=2744'
    'Vortex (Taito do Brasil 1983)'                                                    = 'http://www.ipdb.org/machine.cgi?id=4576'
    'Vulcan (Gottlieb 1977)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2745'
    'Vulcan IV (Rowamet 1982)'                                                         = 'https://www.ipdb.org/machine.cgi?id=5169'
    'WHO dunnit (Bally 1995)'                                                          = 'http://www.ipdb.org/machine.cgi?id=3685'
    'WWF Royal Rumble (Data East 1994)'                                                = 'http://www.ipdb.org/machine.cgi?id=2820'
    'Walkyria (Joctronic 1986)'                                                        = 'https://www.ipdb.org/machine.cgi?id=5556'
    'Warlok (Williams 1982)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2754'
    'Waterworld (Gottlieb 1995)'                                                       = 'http://www.ipdb.org/machine.cgi?id=3793'
    'Wheel (Maresa 1974)'                                                              = 'http://www.ipdb.org/machine.cgi?id=4644'
    'Wheel of Fortune (Stern 2007)'                                                    = 'http://www.ipdb.org/machine.cgi?id=5254'
    'Whirl-Wind (Gottlieb 1958)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2760'
    'Whirlwind (Williams 1990)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2765'
    'White Water (Williams 1993)'                                                      = 'http://www.ipdb.org/machine.cgi?id=2768'
    'Whoa Nellie! Big Juicy Melons (Stern 2015)'                                       = 'http://www.ipdb.org/machine.cgi?id=6252'
    'Whoa Nellie! Big Juicy Melons (WhizBang Pinball 2011)'                            = 'https://www.ipdb.org/machine.cgi?id=5863'
    'Whoa Nellie! Big Juicy Melons - Nude Edition (Stern 2015)'                        = 'http://www.ipdb.org/machine.cgi?id=6252'
    'Wild Card (Williams 1977)'                                                        = 'https://www.ipdb.org/machine.cgi?id=2778'
    'Wild Fyre (Stern 1978)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2783'
    'Wild Life (Gottlieb 1972)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2784'
    'Wild Wild West (Gottlieb 1969)'                                                   = 'http://www.ipdb.org/machine.cgi?id=2787'
    'Wimbledon (Electromatic 1978)'                                                    = 'https://www.ipdb.org/machine.cgi?id=6581'
    'Winner (Williams 1971)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2792'
    'Wipe Out (Gottlieb 1993)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2799'
    'Wizard! (Bally 1975)'                                                             = 'http://www.ipdb.org/machine.cgi?id=2803'
    'Wolf Man (Peyper 1987)'                                                           = 'http://www.ipdb.org/machine.cgi?id=4435'
    'Wonderland (Williams 1955)'                                                       = 'https://www.ipdb.org/machine.cgi?id=2805'
    'World Challenge Soccer (Gottlieb 1994)'                                           = 'http://www.ipdb.org/machine.cgi?id=2808'
    'World Cup (Williams 1978)'                                                        = 'http://www.ipdb.org/machine.cgi?id=2810'
    'World Cup Soccer (Bally 1994)'                                                    = 'http://www.ipdb.org/machine.cgi?id=2811'
    'World Poker Tour (Stern 2006)'                                                    = 'http://www.ipdb.org/machine.cgi?id=5134'
    'World Series (Gottlieb 1972)'                                                     = 'https://www.ipdb.org/machine.cgi?id=2813'
    'World''s Fair Jig-Saw (Rock-ola 1933)'                                            = 'http://www.ipdb.org/machine.cgi?id=1295'
    'X''s & O''s (Bally 1984)'                                                         = 'http://www.ipdb.org/machine.cgi?id=2822'
    'X-Men Magneto LE (Stern 2012)'                                                    = 'https://www.ipdb.org/machine.cgi?id=5823'
    'X-Men Wolverine LE (Stern 2012)'                                                  = 'https://www.ipdb.org/machine.cgi?id=5824'
    'Xenon (Bally 1980)'                                                               = 'http://www.ipdb.org/machine.cgi?id=2821'
    'Yukon (Williams 1971)'                                                            = 'https://www.ipdb.org/machine.cgi?id=2829'
    'Yukon (Special) (Williams 1971)'                                                  = 'https://www.ipdb.org/machine.cgi?id=3533'
    'Zarza (Taito do Brasil 1982)'                                                     = 'http://www.ipdb.org/machine.cgi?id=4584'
    'Zephy (LTD do Brasil 1982)'                                                       = 'https://www.ipdb.org/machine.cgi?id=4592'
    'Zip-A-Doo (Bally 1970)'                                                           = 'http://www.ipdb.org/machine.cgi?id=2840'
    'Zira (Playmatic 1980)'                                                            = 'http://www.ipdb.org/machine.cgi?id=3584'
    'Zodiac (Williams 1971)'                                                           = 'https://www.ipdb.org/machine.cgi?id=2841'
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
    $listView.SelectedItems[0].SubItems[4].Text = $count

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
        $listItem.SubItems.Add($table.Manufacturer) | Out-Null
        $listItem.SubItems.Add($table.Year) | Out-Null
        $listItem.SubItems.Add($table.Details) | Out-Null ## TESTX
        $launchCount = $script:launchCount[[IO.Path]::GetFileNameWithoutExtension($listItem.Tag)]
        if (!$launchCount) { $launchCount = '0' }
        $listItem.SubItems.Add($launchCount) | Out-Null

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

                # Update metadata
                $meta = $script:metadataCache[$filename]

                if (-not $meta) {
                    $meta = @{
                        TableName    = $listView.SelectedItems.Text
                        TableVersion = $listView.SelectedItems.SubItems[2].Text
                        Details      = ''
                        AuthorName   = $listView.SelectedItems.SubItems[1].Text
                    }
                    $script:metadataCache[$filename] = $meta
                }

                $label1.Text = $meta.TableName
                $text = $null
                if ($meta.TableVersion) {
                    $text += "$($meta.TableVersion) "
                }
                if ($meta.AuthorName) {
                    $text += "by $($meta.AuthorName)"
                }
                if ($meta.Details) {
                    $text += " - $($meta.Details) "
                }
                $label2.Text = $text
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
                # e..g "24 (Stern 2009)"
                $name = '{0} ({1} {2})' -f `
                    $listView.SelectedItems.Text, `
                    $listView.SelectedItems.SubItems[1].Text, `
                    $listView.SelectedItems.SubItems[2].Text
                if ($script:puplookup.ContainsKey($name)) {
                    Write-Verbose "F2 pressed. Showing help for '$name'"
                    Start-Process -FilePath $script:puplookup[$name]
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

    $label1 = New-Object -TypeName 'Windows.Forms.Label'
    # $label1.LinkColor = $script:colorScheme.PanelStatus_ForeColor
    $label1.Text = ''
    $label1.Font = New-Object  System.Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
    $label1.Left = 5
    $label1.Top = 4
    $label1.Width = 440
    # $label1.Height = 20
    $label1.AutoSize = $false
    $label1.AutoEllipsis = $true
    $panelStatus.Controls.Add($label1)

    $label2 = New-Object -TypeName 'Windows.Forms.Label'
    $label2.Text = ''
    $label2.Left = 7
    $label2.Top = 37
    $label2.Height = 20
    $label2.Width = 400
    $label2.AutoSize = $false
    $label2.AutoEllipsis = $true
    $panelStatus.Controls.Add($label2)

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
