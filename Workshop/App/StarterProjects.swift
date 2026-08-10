import Foundation
import NintekKit

/// One starter build: the project record plus everything that makes it look
/// like a project someone actually kept.
///
/// A bare `ProjectInput` was the original mistake here — it creates a row with
/// PARTS 0 and EST. COST $0.00, which teaches a new user that a Workshop
/// project is an empty shell. The cut list, the materials and the plan sheet
/// are the whole point, and each is a separate write, so they live together in
/// one value and get seeded as a unit.
struct StarterProject {
    let input: ProjectInput
    /// Bundled plan sheet, drawn by `Scripts/make-starter-plans.swift`.
    let planAsset: String
    let cutList: [CutListInput]
    let materials: [MaterialInput]
}

struct StarterShaperProject {
    let input: ShaperProjectInput
    let planAsset: String
    let cutList: [CutListInput]
}

/// What a brand-new account starts with.
///
/// A workshop app that opens on "No projects yet" asks the user to do the
/// hardest part first — invent something — before it has shown them what a
/// project in here even looks like. So the first sign-in lands on a board that
/// is already running: four builds in the queue and three shop-jig cuts in the
/// Shaper hub. They're ordinary starter builds, editable and deletable like
/// anything else, and they exist mostly to demonstrate the shape of a record.
///
/// Every word, dimension and drawing below is written for this app rather than
/// lifted from a plans site, and the sheets are generated from the same numbers
/// as the cut lists — so if you change a part size, change it in both places.
/// Nothing here links out to third-party content, which is why `sourceUrl` is
/// left empty: there is no original elsewhere.
///
/// Seeding is a **write to the user's real account**, so it happens exactly
/// once, and only when the very first load of that account comes back
/// completely empty — see ``StarterSeeder``.
enum StarterProjects {
    /// Shaper Hub — the browse root. The seeds are jigs to cut on an Origin,
    /// not links to a specific Hub file, so they point at the hub itself.
    private static let shaperHub = "https://hub.shapertools.com/"

    static let projects: [StarterProject] = [
        StarterProject(
            input: ProjectInput(
                title: "Hand Tool Storage Cabinet",
                description: """
                A wall-hung cabinet that keeps chisels, planes and sharpening \
                stones in reach and off the bench. French-cleat mounted, with \
                shallow doors that carry the layout tools so the case depth \
                stays honest at 8".

                1. Break the 3/4" sheet down into the two sides, the top and \
                bottom, and the two fixed shelves. Cut every part that shares a \
                dimension at the same fence setting.
                2. Cut a 3/8" × 1/2" rabbet along the back inside edge of all \
                four case parts to receive the 1/2" back.
                3. Dado the sides for the two fixed shelves — 12-1/2" and 24" up \
                from the inside face of the bottom.
                4. Dry-fit the carcase. Check the diagonals before glue, not after.
                5. Glue and clamp the case, then drop the back into its rabbet \
                and screw it off. The back is what keeps the case square for the \
                rest of its life.
                6. Rip the two cleats from one 4" blank at 45°. The lower half \
                screws to the case, the upper half to the wall studs.
                7. Mill the walnut for the doors and groove the stiles and rails \
                1/4" wide, 3/8" deep, centred.
                8. Cut 3/8" tenons on the rail ends to fit the groove. Test on an \
                offcut first.
                9. Glue the door frames around the 1/4" panels — glue the joints, \
                never the panel.
                10. Fit the doors to the case with 35mm concealed hinges. Aim for \
                an even 1/16" reveal all round.
                11. Lay the tool racks out on the door panels around the tools you \
                actually own, then screw them through the panel from behind.
                12. Break every edge, sand to 180, and finish with three coats of \
                Danish oil.
                13. Hang the wall cleat dead level, then lift the cabinet on. Load \
                the heavy planes low.
                """,
                status: .idea,
                difficulty: .intermediate,
                estimatedHours: 16,
                woodTypes: ["Baltic Birch Plywood", "Walnut"],
                toolsNeeded: ["Table Saw", "Router", "Drill/Driver", "Clamps",
                              "Random Orbit Sander", "Chisels"]
            ),
            planAsset: "plan-hand-tool-cabinet",
            cutList: [
                CutListInput(partName: "Case Side", qty: 2, length: "36\"", width: "8\"",
                             thickness: "3/4\"", material: "Baltic Birch Plywood", sortOrder: 0),
                CutListInput(partName: "Case Top / Bottom", qty: 2, length: "28-1/2\"", width: "8\"",
                             thickness: "3/4\"", material: "Baltic Birch Plywood", sortOrder: 1),
                CutListInput(partName: "Case Back", qty: 1, length: "36\"", width: "30\"",
                             thickness: "1/2\"", material: "Baltic Birch Plywood", sortOrder: 2),
                CutListInput(partName: "Fixed Shelf", qty: 2, length: "28-1/2\"", width: "7-1/4\"",
                             thickness: "3/4\"", material: "Baltic Birch Plywood", sortOrder: 3),
                CutListInput(partName: "French Cleat", qty: 2, length: "28-1/2\"", width: "4\"",
                             thickness: "3/4\"", material: "Baltic Birch Plywood", sortOrder: 4),
                CutListInput(partName: "Door Stile", qty: 4, length: "35-1/2\"", width: "2-1/2\"",
                             thickness: "3/4\"", material: "Walnut", sortOrder: 5),
                CutListInput(partName: "Door Rail", qty: 4, length: "10-1/2\"", width: "2-1/2\"",
                             thickness: "3/4\"", material: "Walnut", sortOrder: 6),
                CutListInput(partName: "Door Panel", qty: 2, length: "31\"", width: "10-1/2\"",
                             thickness: "1/4\"", material: "Baltic Birch Plywood", sortOrder: 7),
                CutListInput(partName: "Door Tool Rack", qty: 6, length: "10-1/2\"", width: "3\"",
                             thickness: "3/4\"", material: "Walnut", sortOrder: 8),
                CutListInput(partName: "Edge Banding", qty: 1, length: "96\"", width: "3/4\"",
                             thickness: "1/8\"", material: "Walnut", sortOrder: 9),
            ],
            materials: [
                MaterialInput(name: "Baltic Birch Plywood, 3/4\"", qtyLabel: "1 sheet (5 × 5)",
                              cost: 95, sortOrder: 0),
                MaterialInput(name: "Baltic Birch Plywood, 1/2\"", qtyLabel: "1 sheet (2 × 4)",
                              cost: 38, sortOrder: 1),
                MaterialInput(name: "Baltic Birch Plywood, 1/4\"", qtyLabel: "1 sheet (2 × 4)",
                              cost: 26, sortOrder: 2),
                MaterialInput(name: "Walnut, 4/4 S2S", qtyLabel: "8 bd ft", cost: 72, sortOrder: 3),
                MaterialInput(name: "Concealed Hinges, 35mm", qtyLabel: "2 pair", cost: 18, sortOrder: 4),
                MaterialInput(name: "Magnetic Catches", qtyLabel: "2", cost: 7, sortOrder: 5),
                MaterialInput(name: "#8 × 1-1/4\" Screws", qtyLabel: "1 box", cost: 8, sortOrder: 6),
                MaterialInput(name: "Wood Glue", qtyLabel: "1 bottle", cost: 9, sortOrder: 7),
                MaterialInput(name: "Danish Oil", qtyLabel: "1 qt", cost: 22, sortOrder: 8),
            ]
        ),

        StarterProject(
            input: ProjectInput(
                title: "How to Build a Walnut Serving Tray",
                description: """
                A small walnut tray with mitred corners, a rabbeted bottom panel \
                and cut-in handles. A one-weekend build that runs entirely on \
                offcuts, and the fastest way to find out whether your mitre sled \
                is actually square.

                1. Mill the walnut to 5/8" thick and rip it to 2-1/4" wide. Cut \
                all four sides from one length so the grain runs round the tray.
                2. Cut a 1/4" wide × 3/8" deep rabbet along the bottom inside edge \
                of all four sides, before you cut the mitres.
                3. Mitre the ends at 45°. Cut the two long sides to 18" and the two \
                short sides to 12", measured on the long points.
                4. Lay out the handle slots on the short sides — 4" long, 3/4" \
                tall, centred — and remove the waste with a router and a straight \
                bit, or by drilling and paring.
                5. Dry-fit with a band clamp. If a corner shows light, adjust the \
                sled, not the joint.
                6. Cut the 1/4" bottom panel to 17-1/4" × 11-1/4" and check it in \
                the rabbets. It should drop in without forcing the mitres open.
                7. Glue all four corners up at once with the panel in place, dry, \
                so it holds the frame square.
                8. Once dry, cut a kerf across each corner on the sled and glue in \
                a contrasting maple spline. This is what stops a mitred tray from \
                failing at the corners.
                9. Trim the splines flush and sand the outside to 220.
                10. Break every edge, especially inside the handles.
                11. Finish with a food-safe oil — three coats, wiped back between \
                each.
                """,
                status: .idea,
                difficulty: .beginner,
                estimatedHours: 6,
                woodTypes: ["Walnut", "Maple"],
                toolsNeeded: ["Table Saw", "Mitre Sled", "Router", "Band Clamp",
                              "Random Orbit Sander"]
            ),
            planAsset: "plan-serving-tray",
            cutList: [
                CutListInput(partName: "Long Side", qty: 2, length: "18\"", width: "2-1/4\"",
                             thickness: "5/8\"", material: "Walnut", sortOrder: 0),
                CutListInput(partName: "Short Side", qty: 2, length: "12\"", width: "2-1/4\"",
                             thickness: "5/8\"", material: "Walnut", sortOrder: 1),
                CutListInput(partName: "Bottom Panel", qty: 1, length: "17-1/4\"", width: "11-1/4\"",
                             thickness: "1/4\"", material: "Maple Plywood", sortOrder: 2),
                CutListInput(partName: "Corner Spline", qty: 4, length: "2-1/4\"", width: "3/4\"",
                             thickness: "1/8\"", material: "Maple", sortOrder: 3),
            ],
            materials: [
                MaterialInput(name: "Walnut, 4/4 S2S", qtyLabel: "3 bd ft", cost: 28, sortOrder: 0),
                MaterialInput(name: "Maple Plywood, 1/4\"", qtyLabel: "1 piece (12 × 24)",
                              cost: 14, sortOrder: 1),
                MaterialInput(name: "Maple Offcut (splines)", qtyLabel: "1", cost: 0, sortOrder: 2),
                MaterialInput(name: "Wood Glue", qtyLabel: "1 bottle", cost: 9, sortOrder: 3),
                MaterialInput(name: "Food-Safe Finishing Oil", qtyLabel: "8 oz", cost: 16, sortOrder: 4),
            ]
        ),

        StarterProject(
            input: ProjectInput(
                title: "DIY Bread Box",
                description: """
                A counter-top bread box with a flip-up front, a vented back panel \
                and a food-safe finish. Small enough to test a joint you haven't \
                cut before without committing a whole board to it.

                1. Mill the maple to 3/4" and glue up panels wide enough for the \
                two sides and the top. Let them sit overnight before flattening.
                2. Cut the sides to 10-1/2" deep × 9-1/2" tall and the top to 16" \
                × 10-1/2".
                3. Cut a 1/2" × 1/2" rabbet along the back inside edge of the \
                sides, top and bottom for the vented back.
                4. Join the case however you like — the plan assumes rabbeted \
                corners, but this is a good box to cut your first through-dovetails \
                on, because nothing structural depends on them.
                5. Drill the vent holes in the 1/2" poplar back: five 3/8" holes in \
                a vertical line, centred, 1-3/8" apart. Bread needs the air; a \
                sealed box goes mouldy.
                6. Glue the case up. Check it for square across the diagonals and \
                for wind on a flat surface.
                7. Drop the back in and pin it. Don't glue it — a fixed solid back \
                will split the case as it moves.
                8. Cut the flip-up front to 14-3/8" × 7-1/2" and fit it with a \
                1/16" reveal each side.
                9. Mortise a pair of 1-1/2" brass butt hinges into the bottom edge \
                of the front and the front edge of the bottom, so the door falls \
                forward and down.
                10. Shape the walnut pull and glue it on 1" down from the top edge \
                of the door.
                11. Fit a magnetic catch at the top so the door stays shut.
                12. Sand to 220, break every edge, and finish with three coats of \
                food-safe oil. Leave it a week before you put bread in it.
                """,
                status: .idea,
                difficulty: .intermediate,
                estimatedHours: 10,
                woodTypes: ["Maple", "Poplar", "Walnut"],
                toolsNeeded: ["Table Saw", "Router", "Drill/Driver", "Chisels",
                              "Random Orbit Sander", "Clamps"]
            ),
            planAsset: "plan-bread-box",
            cutList: [
                CutListInput(partName: "Case Side", qty: 2, length: "10-1/2\"", width: "9-1/2\"",
                             thickness: "3/4\"", material: "Maple", sortOrder: 0),
                CutListInput(partName: "Case Top", qty: 1, length: "16\"", width: "10-1/2\"",
                             thickness: "3/4\"", material: "Maple", sortOrder: 1),
                CutListInput(partName: "Case Bottom", qty: 1, length: "14-1/2\"", width: "10-1/2\"",
                             thickness: "3/4\"", material: "Poplar", sortOrder: 2),
                CutListInput(partName: "Vented Back", qty: 1, length: "14-1/2\"", width: "8-3/4\"",
                             thickness: "1/2\"", material: "Poplar", sortOrder: 3),
                CutListInput(partName: "Flip-Up Front", qty: 1, length: "14-3/8\"", width: "7-1/2\"",
                             thickness: "3/4\"", material: "Maple", sortOrder: 4),
                CutListInput(partName: "Door Pull", qty: 1, length: "6\"", width: "1\"",
                             thickness: "3/4\"", material: "Walnut", sortOrder: 5),
                CutListInput(partName: "Mounting Cleat", qty: 2, length: "9-1/2\"", width: "3/4\"",
                             thickness: "3/4\"", material: "Poplar", sortOrder: 6),
            ],
            materials: [
                MaterialInput(name: "Maple, 4/4 S2S", qtyLabel: "6 bd ft", cost: 48, sortOrder: 0),
                MaterialInput(name: "Poplar, 4/4 S2S", qtyLabel: "4 bd ft", cost: 22, sortOrder: 1),
                MaterialInput(name: "Poplar Panel, 1/2\"", qtyLabel: "1 piece (12 × 24)",
                              cost: 16, sortOrder: 2),
                MaterialInput(name: "Brass Butt Hinges, 1-1/2\"", qtyLabel: "1 pair",
                              cost: 12, sortOrder: 3),
                MaterialInput(name: "Magnetic Catch", qtyLabel: "1", cost: 4, sortOrder: 4),
                MaterialInput(name: "Wood Glue", qtyLabel: "1 bottle", cost: 9, sortOrder: 5),
                MaterialInput(name: "Food-Safe Finishing Oil", qtyLabel: "8 oz", cost: 16, sortOrder: 6),
            ]
        ),

        StarterProject(
            input: ProjectInput(
                title: "DIY Dartboard Cabinet",
                description: """
                A wall cabinet that frames the board, catches the darts that miss \
                and closes on a pair of scoreboards. Mostly a case-and-door \
                exercise, with hardware that has to line up on the first try.

                1. Mill the red oak to 3/4" and rip it to 4-1/2" for the case. The \
                case is only as deep as it needs to be to clear the board and the \
                flights.
                2. Cut the sides to 26" and the top and bottom to 24-1/2".
                3. Rabbet the back inside edge of all four case parts 1/2" × 1/2" \
                for the plywood back.
                4. Cut the corner joints — rabbets are fine here, but this is a \
                good case for box joints, since the end grain shows.
                5. Glue the case up square. A cabinet that's out of square will \
                fight you when you hang the doors.
                6. Fit the 1/2" back into its rabbet and screw it off.
                7. Cut the 20" × 20" backer board and screw it to the back panel, \
                centred. This is what the dartboard's own fixing screws into — \
                never mount a board straight to 1/2" ply.
                8. Mill the door parts. Groove the stiles and rails 1/4" wide × \
                3/8" deep, centred, and cut matching 3/8" tenons on the rails.
                9. Glue each door around its 1/4" panel. Keep them out of winding — \
                twisted doors will never close flat together.
                10. Glue the chalkboard panels to the inside faces of the doors, or \
                rout a second rebate and let them sit in it if you want them \
                replaceable.
                11. Hang the doors on non-mortise hinges, one pair per door, and \
                fit the knobs.
                12. Sand to 180 and finish with three coats of satin poly, sanding \
                lightly between coats. Poly, not oil — this cabinet gets handled \
                with drinks nearby.
                13. Hang the cabinet so the bullseye lands 5' 8" off the floor, \
                then measure 7' 9-1/4" out for the oche.
                """,
                status: .idea,
                difficulty: .intermediate,
                estimatedHours: 12,
                woodTypes: ["Red Oak", "Birch Plywood"],
                toolsNeeded: ["Table Saw", "Mitre Saw", "Router", "Drill/Driver",
                              "Clamps", "Random Orbit Sander"]
            ),
            planAsset: "plan-dartboard-cabinet",
            cutList: [
                CutListInput(partName: "Case Side", qty: 2, length: "26\"", width: "4-1/2\"",
                             thickness: "3/4\"", material: "Red Oak", sortOrder: 0),
                CutListInput(partName: "Case Top / Bottom", qty: 2, length: "24-1/2\"", width: "4-1/2\"",
                             thickness: "3/4\"", material: "Red Oak", sortOrder: 1),
                CutListInput(partName: "Back Panel", qty: 1, length: "26\"", width: "26\"",
                             thickness: "1/2\"", material: "Birch Plywood", sortOrder: 2),
                CutListInput(partName: "Backer Board", qty: 1, length: "20\"", width: "20\"",
                             thickness: "3/4\"", material: "Birch Plywood", sortOrder: 3),
                CutListInput(partName: "Door Stile", qty: 4, length: "26\"", width: "2-1/4\"",
                             thickness: "3/4\"", material: "Red Oak", sortOrder: 4),
                CutListInput(partName: "Door Rail", qty: 4, length: "9\"", width: "2-1/4\"",
                             thickness: "3/4\"", material: "Red Oak", sortOrder: 5),
                CutListInput(partName: "Door Panel", qty: 2, length: "22\"", width: "9\"",
                             thickness: "1/4\"", material: "Birch Plywood", sortOrder: 6),
                CutListInput(partName: "Scoreboard Panel", qty: 2, length: "22\"", width: "9\"",
                             thickness: "1/4\"", material: "Chalkboard Panel", sortOrder: 7),
            ],
            materials: [
                MaterialInput(name: "Red Oak, 4/4 S2S", qtyLabel: "12 bd ft", cost: 66, sortOrder: 0),
                MaterialInput(name: "Birch Plywood, 1/2\"", qtyLabel: "1 sheet (4 × 4)",
                              cost: 42, sortOrder: 1),
                MaterialInput(name: "Birch Plywood, 1/4\"", qtyLabel: "1 sheet (2 × 4)",
                              cost: 24, sortOrder: 2),
                MaterialInput(name: "Chalkboard Panel", qtyLabel: "1 sheet (2 × 4)",
                              cost: 18, sortOrder: 3),
                MaterialInput(name: "Non-Mortise Hinges", qtyLabel: "2 pair", cost: 16, sortOrder: 4),
                MaterialInput(name: "Cabinet Knobs", qtyLabel: "2", cost: 9, sortOrder: 5),
                MaterialInput(name: "Wood Glue", qtyLabel: "1 bottle", cost: 9, sortOrder: 6),
                MaterialInput(name: "Satin Polyurethane", qtyLabel: "1 qt", cost: 24, sortOrder: 7),
            ]
        ),
    ]

    static let shaperProjects: [StarterShaperProject] = [
        StarterShaperProject(
            input: ShaperProjectInput(
                title: "Push Sticks",
                shaperUrl: shaperHub,
                description: """
                A set of push sticks cut from scrap ply. The first thing worth \
                making on the Origin: the shape matters more than the material, \
                and they're meant to be remade the moment one gets chewed up.
                """,
                materials: [ShaperMaterial(name: "Baltic Birch Plywood, 1/2\"", qty: "1 offcut")],
                instructions: """
                1. Tape a 1/2" offcut down to the spoilboard and lay the tape so \
                the whole outline stays in view through the cut.
                2. Scan the workspace, then place the profile. Cut the 1" finger \
                hole first, while the blank is still fully anchored.
                3. Cut the outside profile with a 1/8" bit at full depth in two \
                passes, leaving tabs.
                4. Free the parts, pare the tabs back and break every edge by hand \
                — a rounded grip is the whole reason for making your own.
                5. Glue a 1/2" heel to the back of the push block so it drives the \
                stock rather than skidding over it.
                6. Cut two of each. You will lose one to the blade eventually, and \
                that is exactly what they are for.
                """
            ),
            planAsset: "plan-push-sticks",
            cutList: [
                CutListInput(partName: "Long Push Stick", qty: 2, length: "14\"", width: "5-1/2\"",
                             thickness: "1/2\"", material: "Baltic Birch Plywood", sortOrder: 0),
                CutListInput(partName: "Push Block", qty: 2, length: "8\"", width: "5-1/2\"",
                             thickness: "1/2\"", material: "Baltic Birch Plywood", sortOrder: 1),
                CutListInput(partName: "Glue-On Heel", qty: 2, length: "8\"", width: "1/2\"",
                             thickness: "1/2\"", material: "Baltic Birch Plywood", sortOrder: 2),
            ]
        ),

        StarterShaperProject(
            input: ShaperProjectInput(
                title: "Clamping Squares",
                shaperUrl: shaperHub,
                description: """
                90° squares that hold a carcase corner true while the glue sets. \
                Cut in pairs from one blank, with a relief hole at the inside \
                corner so squeeze-out has somewhere to go and never glues the jig \
                to the work.
                """,
                materials: [ShaperMaterial(name: "Baltic Birch Plywood, 3/4\"",
                                           qty: "1 blank (10-1/2 × 8)")],
                instructions: """
                1. Cut a 10-1/2" × 8" blank from 3/4" ply. Two squares nest off it \
                with the second turned 180°.
                2. Tape the blank down and scan. Place both outlines before you cut \
                anything.
                3. Cut the 1" relief hole at each inside corner first. This is the \
                detail that makes the jig usable — without it, glue squeeze-out \
                welds the square to the carcase.
                4. Cut the clamp windows next, while the blank is still whole.
                5. Cut the outside profiles last, so each part stays anchored to \
                the sheet as long as possible.
                6. Check every square against a known reference before it earns a \
                place on the glue-up shelf. A clamping square that isn't square is \
                worse than none.
                7. Seal them with a wipe of oil or paste wax so glue pops off \
                instead of soaking in.
                """
            ),
            planAsset: "plan-clamping-squares",
            cutList: [
                CutListInput(partName: "Clamping Square", qty: 4, length: "8\"", width: "8\"",
                             thickness: "3/4\"", material: "Baltic Birch Plywood", sortOrder: 0),
            ]
        ),

        StarterShaperProject(
            input: ShaperProjectInput(
                title: "Festool Kapex Zero Clearance Fence",
                shaperUrl: shaperHub,
                description: """
                A zero-clearance sub-fence for the Kapex, so cross-cuts break out \
                clean on both faces. Cut to the fence's own bolt pattern, then let \
                the saw open its own kerf on the first cut.
                """,
                materials: [
                    ShaperMaterial(name: "MDF or Baltic Birch, 1/2\"", qty: "2 pieces (13 × 3-1/2)"),
                    ShaperMaterial(name: "M6 hardware to suit the fence", qty: "1 set"),
                ],
                instructions: """
                1. Measure the slot spacing off your own saw rather than off this \
                drawing — fences vary between production runs, and a sub-fence that \
                doesn't bolt up is scrap.
                2. Cut two blanks to 13" × 3-1/2" from 1/2" stock.
                3. Tape and scan, then cut the three M6 slots. Slots, not holes — \
                they give you the adjustment you'll want when you square the fence \
                up.
                4. Counterbore each slot 7/8" diameter so the bolt heads sit below \
                the face. A proud bolt head is what the workpiece catches on.
                5. Bolt both halves to the saw and set them just clear of the blade \
                path.
                6. Make one full-depth cut at 90° to let the blade open its own \
                kerf, then re-check for square.
                7. Cut a fresh pair whenever you've bevelled often enough to widen \
                the kerf — that's the point of making them from offcuts.
                """
            ),
            planAsset: "plan-kapex-fence",
            cutList: [
                CutListInput(partName: "Sub-Fence", qty: 2, length: "13\"", width: "3-1/2\"",
                             thickness: "1/2\"", material: "MDF", sortOrder: 0),
            ]
        ),
    ]
}

/// Creates ``StarterProjects`` in a genuinely new account, once.
///
/// The guard is deliberately conservative, because the failure mode is writing
/// junk into an established workshop: it only fires when a load succeeds *and*
/// the account has no projects, no Shaper projects and no templates. Whichever
/// way that first load goes — seeded or already full — the account is marked,
/// so a user who later empties their board never gets it refilled underneath
/// them. The mark is per user key, so a second account on the same device is
/// still treated as new.
enum StarterSeeder {
    private static let prefix = "ws.seededStarterContent."

    private static func key(_ userKey: String?) -> String { prefix + (userKey ?? "unknown") }

    static func hasRun(userKey: String?, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key(userKey))
    }

    static func markRun(userKey: String?, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key(userKey))
    }

    /// Forget the once-only marker after the account itself has been deleted.
    /// If the same Apple/Microsoft identity later creates a fresh Workshop
    /// account, it is genuinely new and should receive the starter board again.
    static func clearRun(userKey: String?, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(userKey))
    }

    /// Creates every starter record, one project at a time so the dashboard's
    /// default "last updated" order matches the order they're listed in above.
    /// Returns the number of projects created; a partial failure keeps whatever
    /// landed, because half a starter board still beats an empty one.
    @discardableResult
    static func seed(api: WorkshopAPI) async -> Int {
        var created = 0
        for seed in StarterProjects.projects.reversed() {
            do {
                let project = try await api.createProject(seed.input)
                created += 1
                await attachDetail(seed, projectId: project.id, api: api)
            } catch {
                log("project", seed.input.title, error)
            }
        }
        for seed in StarterProjects.shaperProjects.reversed() {
            do {
                let project = try await api.createShaperProject(seed.input)
                created += 1
                await attachShaperDetail(seed, projectId: project.id, api: api)
            } catch {
                log("Shaper project", seed.input.title, error)
            }
        }
        return created
    }

    /// The plan sheet, the cut list and the materials, in parallel.
    ///
    /// Each is its own request and there are a dozen or more per project, so run
    /// serially this would take long enough for the user to watch it happen.
    /// None of them depend on each other, and row order travels in `sortOrder`
    /// rather than in insertion order, so they can all go at once. Every one is
    /// individually non-fatal: a project with nine of its ten parts is still
    /// worth having.
    private static func attachDetail(_ seed: StarterProject, projectId: Int, api: WorkshopAPI) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                guard let file = planFile(seed.planAsset) else { return }
                do { try await api.uploadImage(projectId: projectId, kind: .sketch, file: file) }
                catch { log("plan sheet", seed.planAsset, error) }
            }
            for item in seed.cutList {
                group.addTask {
                    do { try await api.addCutItem(projectId: projectId, item) }
                    catch { log("cut item", item.partName, error) }
                }
            }
            for material in seed.materials {
                group.addTask {
                    do { try await api.addMaterial(projectId: projectId, material) }
                    catch { log("material", material.name, error) }
                }
            }
        }
    }

    private static func attachShaperDetail(_ seed: StarterShaperProject, projectId: Int,
                                           api: WorkshopAPI) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                guard let file = planFile(seed.planAsset) else { return }
                do { try await api.uploadShaperImage(shaperProjectId: projectId, file: file) }
                catch { log("Shaper plan", seed.planAsset, error) }
            }
            for item in seed.cutList {
                group.addTask {
                    do { try await api.addShaperCutItem(shaperProjectId: projectId, item) }
                    catch { log("Shaper cut item", item.partName, error) }
                }
            }
        }
    }

    /// Loads a bundled plan sheet. Returns nil rather than throwing — a missing
    /// resource should cost the project its drawing, not its existence.
    private static func planFile(_ asset: String) -> MultipartFile? {
        guard let url = Bundle.main.url(forResource: asset, withExtension: "png"),
              let data = try? Data(contentsOf: url) else {
            NSLog("[Workshop] Starter plan '%@.png' missing from the bundle", asset)
            return nil
        }
        return MultipartFile(filename: "\(asset).png", mimeType: "image/png", data: data)
    }

    private static func log(_ kind: String, _ name: String, _ error: Error) {
        NSLog("[Workshop] Starter %@ '%@' failed: %@", kind, name, String(describing: error))
    }
}
