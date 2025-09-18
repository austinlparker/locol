<!--
Downloaded via https://llm.codes by @steipete on September 13, 2025 at 09:46 AM
Source URL: https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb
Total pages processed: 188
URLs filtered: Yes
Content de-duplicated: Yes
Availability strings filtered: Yes
Code blocks only: No
-->

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb

Framework

# GRDB

A toolkit for SQLite databases, with a focus on application development

## Overview

Use this library to save your application’s permanent data into SQLite databases. It comes with built-in tools that address common needs:

- **SQL Generation**

Enhance your application models with persistence and fetching methods, so that you don’t have to deal with SQL and raw database rows when you don’t want to.

- **Database Observation**

Get notifications when database values are modified.

- **Robust Concurrency**

Multi-threaded applications can efficiently use their databases, including WAL databases that support concurrent reads and writes.

- **Migrations**

Evolve the schema of your database as you ship new versions of your application.

- **Leverage your SQLite skills**

Not all developers need advanced SQLite features. But when you do, GRDB is as sharp as you want it to be. Come with your SQL and SQLite skills, or learn new ones as you go!

## Usage

Start using the database in four steps:

import GRDB

// 1. Open a database connection
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// 2. Define the database schema
try dbQueue.write { db in
try db.create(table: "player") { t in
t.primaryKey("id", .text)
t.column("name", .text).notNull()
t.column("score", .integer).notNull()
}
}

// 3. Define a record type
struct Player: Codable, FetchableRecord, PersistableRecord {
var id: String
var name: String
var score: Int
}

// 4. Write and read in the database
try dbQueue.write { db in
try Player(id: "1", name: "Arthur", score: 100).insert(db)
try Player(id: "2", name: "Barbara", score: 1000).insert(db)
}

let players: [Player] = try dbQueue.read { db in
try Player.fetchAll(db)
}

## Links and Companion Libraries

- GitHub Repository

- Installation Instructions, encryption with SQLCipher, custom SQLite builds

- GRDBQuery: the SwiftUI companion for GRDB.

- GRDBSnapshotTesting: Test your database.

## Topics

### Fundamentals

Open database connections to SQLite databases.

SQL is the fundamental language for accessing SQLite databases.

GRDB helps your app deal with Swift and SQLite concurrency.

Transactions and Savepoints

Precise transaction handling.

### Migrations and The Database Schema

Define or query the database schema.

Migrations allow you to evolve your database schema over time.

### Records and the Query Interface

Record types and the query interface build SQL queries for you.

Recommended Practices for Designing Record Types

Leverage the best of record types and associations.

Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

Single-Row Tables

The setup for database tables that should contain a single row.

### Application Tools

Observe database changes and transactions.

Search a corpus of textual documents.

Store and use JSON values in SQLite databases.

`enum DatabasePublishers`

A namespace for database Combine publishers.

### Extended Modules

CoreFoundation

Foundation

Swift

- GRDB
- Overview
- Usage
- Links and Companion Libraries
- Topics

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/images/GRDB/GRDBLogo.png

�PNG


IHDR�����sRGB���DeXIfMM\*�i�����Ec��@IDATx�}\`\\ŵ��\]�.K�eٸ��q/4���bI���PB�{y�R�@�K�\_^

Y4��?v���ėt��C�IH�rlw=��$7ͯ���ڥ-�.)㷊j��(��c�/h.� U�ǋ�m$�� ���+�i��W-�R#�P\

��@�H��\_�G"��˥�y��{�SoD��I�������ٌ�M\
�g�ϑK�ϕ��%/=I�\
���ސx�G��1���Wr��=\
�\
��Ć�nn�$�S�7�dߏ��iގ\*�&�6ͽ�Bp��9OÛ��ǘE� �� ���J�IK�\

;��Q\\t��圹r���帑#���\]3���-T��
����w-�s�y���Mn{�T�����i ���N��9���h\|2w!8��3�3:����5ΐO�?Y��R�܆��p<�^���F,弘�\\�.��͝��gw�v�uA\_�ۧ����a}k�޵��\]y+f/?���ȉ��̐��9
��L�:v�V���V� ώЋ6�/xA�5ƛc��ihm���u���ryR�7Ȣ�%��}�SD��c6�z��8���{
fw,�ϙrٹ�IZJ��{f���(�\\xo�cx�\\��:;�U֩\[��H�aE�iW�\
\\�띩�q���Ԟ���?P\[�y��\

O� {�0��+�a}\_��a��^Ck~�ʴ(sި,y�K�e�A�Ac

��8t���}
�0���)I~9�"��\*�ή��5Y\|�/�7l�ſ߀���uͨ)����xjTZY-~a���t�㷿"�r�䃍;����Y�mD\]�3�e��Љ!yk�z��~#���2��ߏ&�Hl�W���#\_��}� S�)G�a���܍�O�˧�KyC����D�~Nμi��{�by���x����8Uses�eٗ\\��LWl����?Q��\_L����\_�\_<�TG�˂R�{&y����,�\_�
p��8f���5��9������NL�"�Hv^#9��t
fgl����w^�+%u:�\*�Xv#fXOD�e �r���C2r�X4lf\_

�S~��mھSfN�)�X��Ȕ�\_3L���Jy��%��2n�1R��KV@Ўה\]�Մk�c��8�̉�� $�b�N�qٹ�rejQ����A�\[ڧB{��u�&y����x4�֔Ȩ)�P����\

�$2hH�c�/����b����H��xk�&���\`�ǌС�3O�/\_x��gg�ֽ���0�\*\*+�ir%e�0�ol�\[6vi��í;���^���6�:�X $:8���Z�vs��8��\

˖�6��lk��k?�'^yCr�sd<�f΂��b�A��������8�chR�9)l\
�\
nD���)���.(˛��\|fX#�/�"/�1��o��A�"v�Y.��!��FX{!�<��R�w�\

U�\]Ҹ#��^{{����\*9���#,�p� ;8��k�<\_� q��i)�C���u��U/�����%��2��W�����o�gа�c^���S�R\]Q޹�ׅ�����1��ק9���8^��3g�8i��j\
����r�\`uy����@�9�uuT��U�'!,3�i�4ë��w�<�\`0�0gqY�A�@X��W�J�'��G�Ͳ��eK���\_��~OT�"Q�پ�\]&�x{��NQ�W�-{\`\

�����F�������R�ꃢ4l�J��JR��$M%�O�޵���$+'\[�?F�\]u�9�m@ƍ����l���4\
������P��ɲ���:�������4(Zv�J6����\
�I���zs��W�#�zG����-��:\
������s�<�K%Uj��\\\]&�����^l�V���NT�U�6ʼSN���tl�2����\\��:��t�I+\|�\`�p\[��p�}�����x\]i#5������I�����1��4̸l}��\\�4ư��}1��c嘜ց/��J~��+D��=�P���D8k�d����ɧ着5�L��F\*�Ƨ�l����.���9}0�5m�s�&�IɆ-(zi�lؠ������a��0����\`��=ǥ��ä\]��w�i�q��5���K~\|���Gi9��W��pA�����f����v�����������WY)�FF~#�\[$��Vi��oR�༳�\_�J�!{p�"$�l��n1p�Z��v���p�����4�en��\`����e�^��Z��1q���r���0��#^�����c���~�䫲CR1,�B��u�@��q��'OW�\_����}�@���ė�+���6m�&ɩ�2��\

�T��l���r\

@D�%�l��%��SR�\[��X�#~Rd<����t.M0����&d�8rx�L�+Sz=��xD��6�a�n74K�֪����uNq��'Q�O}�B��L���6�{���E�p�O}c���\\#\

I�nB!�o�O�t�6��l�h�k ��$�M;/�lxL^{�50�Z+Kz�C����D:�#��T����g$$�b���C���6��\`��Q��$9'�-��O��M˥q�j\
���P���\|c�z�a4hr!�6��-c���;��:x�N��ޝ��m������W��m��d;\|$Y)M�3O?+�z�5�h�yr�'?!�;�Q�+�@�ȣ#��;��u�Qr%���r\
���\|�I{9�v�\_�m<�\|/^�̟�!:M�뱻;W��u��C�S%����-�s��v��1R8N=����~���nl��"�kJ���R��\]i�.�����h��N=����ԱǨoUء��@L����ZZYU\
4ڵRVU+�)I2g�L�5k�̘1Y2� r\

�UeC���9�ӌW��&�ޖ��M�4l���+׻,��\`\
O �m.����'�{�����Q��.������! ��� �AM��Ţ��T\]�\\�����{!\_��}F�ܽ/�뚅�g"�y�i�8����,}�uf����{�%Ki�^�i��z��sc�6�+�i�x�ڤ ��0U���n�Y���7�#(���-+�a�\*i���Bl�F�r&�s�Y+M<̕����Ay�y�՛�Y��2\|��A����RN�@ё��@%�+\*+d��rye�6 ��Cg�Ѣ��������/���R�M���C?󭾐�o�Q�&�\]T\`�)�r�i\]��m(
��O��mo�2@D���o\`

V�1��Bt+8N+��x��jl�4��3Y��6��7TU��RNT��\|C�.i�Eg!M�.��&y�Hָ�RW�G,�����YZ�������\
�ߏz%oh����� �fK��d�$3�/4O� XP�(Wa\
���R?R�Ù���//�'�4�F�RNӧ���j�\
�KR��\
͘24M�0�@�\|y�<��RvV5˿�9af�\

�K@����A��΍M~i�Z FP7D��F@\
SN�4��((O�6cvQ����Iu�^��(�F��^ff~��͕��sb�l}�99���p�#Rr����T�珐����R����Ҳr��)�e�� ��4!�0cHŐ�+-��&�\
���̀V��!��U$ِg\
f���x������R�L���=ר秶G{N�ix�$�.�\_��ݍ��7K��rB��0�HN��4�dbe^�#P�8 ��\|b�9��v�xGҋ�I��uR��Q���\\�,;Q&�p�?m\

\|ЇEtJ.l��m��G?��%�{B韛^(�9X�İ0\*/E�?e�<��R6��$~��n�����\*��D�Nt\_�Ɖ3�sMIz0��B����%��Y���D��\

B��av�z\�+�#}�W�f#A� ��@��ءX��\
�2�%'��V�R�&�n(#�1��J��d�T�/�qyP���N��6��}����k<\*э�q�̽\`�)$X�jI�ᇿM��Ғ�e����Qj8���a���\\#�{�;j�KK����sۆ6g�+���i���G7�<2KW��6\
g$@6V�e&�q��������%p��r͜�������2�sU:�M�9}k�9�plҠ�)� ��e��<�Q\
�pxkOF��DN��ë������;�A' p�&�\
��9�$8�$��.W��\
҃Yr�E�Hyy�����!�45h'g\`����'ʄ��a�f���p�Lٍ�(?��\|�m0�n�C�Tg�~�eS/�E\[��m���3wl���@#2���cQ�\*8��4�ڔv���t\*)��dG%Q(�ظ������ufp��zf�P�K$K0^#�N�bSN�.$<�OB�x~��i�S�K�E��pO��v,�����a��C;�\
�������Y$�0��r��,Ȳ�U2��s\|X���(8(�2;�78�fFٰ��쪓?\*w��c{YH��U�\
��Y�q�ia��6��S'?��-�B�\
Z����0��\

L���.����\
Cb���\|=I�mҠS�̈́�))���t��'\W3d�% ��:�B֙RL9 -�Dd�h1�F�C����\[z�����LY;�d������L�;ei���l�����!�s�� ����޴����k��˟(��L3j�´�ĀBw&��dԹ\
�7@�����$�4!Y�\|6�5���8�a�f�d�G���Q+�Ǟ(�)����")Pdc$�i,��I���"d� y򹓆tpKl{\

U��n����C3\|� ���߄ץÐ��V.����\[�G�Ý'��Q�dС����hR��� �e�G1;Ry��G��UZ�n���1f�%� p��YIL��M�"�\

��P�j��.�1$A�C��βm5R<(U\
06w䏲�9#�l�Wu6�k\`ӁF��EHo24�F\

R7A3�Jq�:UN�(�k����1K���R2w\*p8\`���/�����\

W�iї�gC��a0$\
�eAA�ѧ(Xhz��2yiL\]��i��b�ٷ��ě��O��o�\*o�;�A�\_�Ӗf\`�cm�I\]\|���\\D?�� L.��j����1g���f��X�Y��
r���uOG�αWo�����8�^{Io��͕ͥ

�hŤ���YC@H.����Xv�~�(a��J�M��9�0)�-�n�g�\]���@GR��=Ufr�S�d(K}j{m��r�0��ym���!\\��v 83?+����V�o枨J��̛�B��.�Y(g��Q\[\]�!c
Re\_m��i�7�c)��O\*�P���l3x�^�Iex
٨ LAَ�dZ�a-�����~�ո

҂��d\
9n�r\*��\]�̇�}�L���Y��T�9�?�{��M�^��E��c��si�����'�X�9s/gL��鶔:h��!Ӑ딓���T�k�@x�O��6� ����I"��ʑ��r:o�R
A��:q/�0���06�<
���\*�vT�z�0�z��\_9Ls����Lu:;R�rK��0�er0���

8O��LŪyj2P�A:=@�
���hb͂(;\|
8����dt���ޛ�\_� ���o�.�h�ip�<\\9C�ሠ�L��j�p�՛\[�\
wQ.��0�dW�#I ���0K���KV�\`zJ6��U�4��S����?�\\G�#��\

0�.@�?F���<� w���{X��M��G�a���k��g��{��K<�c=��ܳ\]\`�95ns��8

���%����h����y�\
����a�L,��!��JF�-��S��D\]~ �4�л�\\���^��W��tώO�$$�gw+�G���y�+g0���8�8\
ɕ�<8�a� ���(7��^:\

�pȢ����ӆ�i�+uܥ@Cr\

���پ����/F�~�P��y�pw�{Z)xP��;�Dr�n���!P����r�\
p�^0sO� ��,�n\`����P�\`�{r����\\d����ː�@\\��A�F�{�����hP�H�����?�n�@�hX�E�I��7萅���\_��{�^A�Gnç����jW$��r��$�������F��e����N���ܓ<#�0��M�\`衹��}\`��p=��1,j.u�1\]{H���e��(?H��ӟ�\[�;�\|\_��p;�\\�g\
O��@"9U��r�\

?��果A~Ɂ�N��bvDa�r�)�@�,O��s�c��=,����w���G'
�;�=w����-!���tO<����0o��Z\[.�b.3Po���ĮNtM�\*��?o��m(�P�� r��l3l\
)P�(�@����.枺��枤�"��l�1��:�=����$�OL+���bkʢe�H�-�{\_�9{��=YAv�������t7�AA�д��2�8Tq&�L�i!h��f�fsF�3#p�N�:�p�J��'\[��}\|�i�˚{��Q �܄��I�C�l\_�:���X}��:�B�n���tO7��Y�7�!�j\
M9�� �՘�S��p��A�\\�%���{"K\]S��z=���fG�D���Z�4���yD��\\���\\pK�1�.�\`���s�2�ԯ���e1����~?Z1X���C��pr�Kq�'چ�Bǿ�8��\]���\*��f����F��f��\*U���&����(�8��;����4�m@�&�l�X:�tob-X(�Bd���e���!jqqՕ�L�%AoE���<�ߛ�{�}����F��,�P6�M�æR����1ú\*�L�j�~��a��8���{+$3L\`�b#�G���pQ�p\*Ͷ\]ݙ�!L�����L�=���8�y
ݚ'(��M2�\*�iNy�IM P���@A�J:��G����

r#~
�Sw�5�ނw{4�dYțFX�(H8JsOcWL�K\*W� 9��\[�{r�\
&��,k���\*���\_����u�ٺ�ёڇ��s����YsO\
�΢���p�0q�p��==�{6c튻�n� .��\
��Sփ��๤�c�;�{b�9j�u�m��خ����!��+�M��Ŭ�\\�{~�1�dC�ئذ�\
Fp{N�)/c��ᇊA#��n��i��A#SnJ�uX\

IDAT׎t9�D�P��1����v��������'4�En������sd��D���a\`8�+t+O�sѬ��)ͻ�����z!t���.�x�Ț{�N-�43��x��7� 'O�{������N�gJ8r��G��s���\_��y�:�;��6��0����\_��RUH�H�g�o�Lk�=����8��Ngm��5����p\[\`��p��'���{ݿ��#��i�Xq��9a��^x���v0�A��8·rƦU��5�o��=�=��l�����\*�f��Ɏ��\
K�;V-D��\]:���nN���\\%JJ��Z(;�{�vs�b��!\[�#�%)��&�jS\*L�n�'�݃���=��tOJ��,�0M�����CVB��}g��{�~��&��\[�� ��pGhl�Ĵ5�t���ҭ}1���N$��\`��M���#4Ц����z��RoѶ4��^�@������{��<�a�o�~Z�i��mף4�Z�AN����C��ƣcݏ�᰹'X3#���o(�c��E �E313:���4�~$��Y�&��B��\
���\\�#�i�\_�mY��/�Zw��$ho�%(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(��@�\
$(pP�P�����<��\

���w7�rĸ(\[ 8��.V��ݱ�9��z�<.�����Λ�m���^O�G&����f<����ԓ';�=���73��i����x��$\[�\`�'���p��d���ш����˭���:�n�A��\\�i��x�z��pt�.��\
�WG�v��&'p��%�-$z^��s��/����Q�ԁt���LO������H@��Ϋ��0ʙH�����W�2����P���E/�}q��f�{�iN�P��!�A�"�O��s��� y��ވ�G#��🂷���7}hN��=�1�҉\_����{:֌�HIv���f"�D���'ggn�e�/��P�@��\
����r��}���U���!L��z!G9�x�o���<��kO\\�R���Htq�!��C���\
�"�-���s�}Ը?�%�i!~}�\[�����{\*��\[�����z���s����X�p$���<x���鞠��'��M���ʯ�\
�d���kCE��U���:� =�2<\|ɓ�C9%�q�b鎅���"x�T\[��\
4h\*"Ԟ����:�Py\
�7ï������^��\
4��Uޗ\\��kn�\_�#h��\]qh�Dz#�6�MN�7�+׮�p�3H�v�v��}��Ÿ��'�\_�@�ō�����d�I#Fq\*%�@�~7������He6#;���-�ld�m�%�"��L\]yR��W�v��f�;"��W�q�p�\*G�~'��w(��\

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseconnections

- GRDB
- Database Connections

API Collection

# Database Connections

Open database connections to SQLite databases.

## Overview

GRDB provides two classes for accessing SQLite databases: `DatabaseQueue` and `DatabasePool`:

import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")

The differences are:

- `DatabasePool` allows concurrent database accesses (this can improve the performance of multithreaded applications).

- `DatabasePool` opens your SQLite database in the WAL mode.

- `DatabaseQueue` supports In-Memory Databases.

**If you are not sure, choose `DatabaseQueue`.** You will always be able to switch to `DatabasePool` later.

## Opening a Connection

You need a path to a database file in order to open a database connection.

**When the SQLite file is ready-made, and you do not intend to modify its content**, then add the database file as a resource of your Xcode project or Swift package, and open a read-only database connection:

// HOW TO open a read-only connection to a database resource

// Get the path to the database resource.
// Replace `Bundle.main` with `Bundle.module` when you write a Swift Package.
if let dbPath = Bundle.main.path(forResource: "db", ofType: "sqlite")

if let dbPath {
// If the resource exists, open a read-only connection.
// Writes are disallowed because resources can not be modified.
var config = Configuration()
config.readonly = true
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
} else {
// The database resource can not be found.
// Fix your setup, or report the problem to the user.
}

**If the application creates or writes in the database**, then first choose a proper location for the database file. Document-based applications will let the user pick a location. Apps that use the database as a global storage will prefer the Application Support directory.

The sample code below creates or opens a database file inside its dedicated directory. On the first run, a new empty database file is created. On subsequent runs, the directory and database file already exist, so it just opens a connection:

// HOW TO create an empty database, or open an existing database file

// Create the "Application Support/MyDatabase" directory if needed
let fileManager = FileManager.default
let appSupportURL = try fileManager.url(
for: .applicationSupportDirectory, in: .userDomainMask,
appropriateFor: nil, create: true)
let directoryURL = appSupportURL.appendingPathComponent("MyDatabase", isDirectory: true)
try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

// Open or create the database
let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
let dbQueue = try DatabaseQueue(path: databaseURL.path)

## Closing Connections

Database connections are automatically closed when `DatabaseQueue` or `DatabasePool` instances are deinitialized.

If the correct execution of your program depends on precise database closing, perform an explicit call to `close()`. This method may fail and create zombie connections, so please check its detailed documentation.

## Next Steps

Once connected to the database, your next steps are probably:

- Define the structure of newly created databases: see Migrations.

- If you intend to write SQL, see SQL, Prepared Statements, Rows, and Values. Otherwise, see Records and the Query Interface.

Even if you plan to keep your project mundane and simple, take the time to read the Concurrency guide eventually.

## Topics

### Configuring database connections

`struct Configuration`

The configuration of a database connection.

### Connections for read and write accesses

`class DatabaseQueue`

A database connection that serializes accesses to an SQLite database.

`class DatabasePool`

A database connection that allows concurrent accesses to an SQLite database.

### Read-only connections on an unchanging database content

`class DatabaseSnapshot`

A database connection that serializes accesses to an unchanging database content, as it existed at the moment the snapshot was created.

`class DatabaseSnapshotPool`

A database connection that allows concurrent accesses to an unchanging database content, as it existed at the moment the snapshot was created.

### Using database connections

`class Database`

An SQLite connection.

`struct DatabaseError`

A `DatabaseError` describes an SQLite error.

## See Also

### Fundamentals

SQL is the fundamental language for accessing SQLite databases.

GRDB helps your app deal with Swift and SQLite concurrency.

Transactions and Savepoints

Precise transaction handling.

- Database Connections
- Overview
- Opening a Connection
- Closing Connections
- Next Steps
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlsupport

- GRDB
- SQL, Prepared Statements, Rows, and Values

API Collection

# SQL, Prepared Statements, Rows, and Values

SQL is the fundamental language for accessing SQLite databases.

## Overview

This section of the documentation focuses on low-level SQLite concepts: the SQL language, prepared statements, database rows and values.

If SQL is not your cup of tea, jump to Records and the Query Interface 🙂

## SQL Support

GRDB has a wide support for SQL.

Once connected with one of the Database Connections, you can execute raw SQL statements:

try dbQueue.write { db in
try db.execute(sql: """
INSERT INTO player (name, score) VALUES (?, ?);
INSERT INTO player (name, score) VALUES (?, ?);
""", arguments: ["Arthur", 500, "Barbara", 1000])
}

Build a prepared `Statement` and lazily iterate a `DatabaseCursor` of `Row`:

try dbQueue.read { db in
let sql = "SELECT id, score FROM player WHERE name = ?"
let statement = try db.makeStatement(sql: sql)
let rows = try Row.fetchCursor(statement, arguments: ["O'Brien"])
while let row = try rows.next() {
let id: Int64 = row[0]
let score: Int = row[1]
}
}

Leverage `SQLRequest` and `FetchableRecord` for defining streamlined apis with powerful SQL interpolation features:

struct Player: Decodable {
var id: Int64
var name: String
var score: Int
}

extension Player: FetchableRecord {

"SELECT * FROM player WHERE name = \(name)"
}

"SELECT MAX(score) FROM player"
}
}

try dbQueue.read { db in
let players = try Player.filter(name: "O'Reilly").fetchAll(db) // [Player]
let maxScore = try Player.maximumScore().fetchOne(db) // Int?
}

For a more detailed overview, see SQLite API.

## Topics

### Fundamental Database Types

`class Statement`

A prepared statement.

`class Row`

A database row.

`struct DatabaseValue`

A value stored in a database table.

`protocol DatabaseCursor`

A cursor that lazily iterates the results of a prepared `Statement`.

### SQL Literals and Requests

`struct SQL`

An SQL literal.

`struct SQLRequest`

An SQL request that can decode database rows.

Return as many question marks separated with commas as the _count_ argument.

### Database Values

`struct DatabaseDateComponents`

A database value that holds date components.

`protocol DatabaseValueConvertible`

A type that can convert itself into and out of a database value.

`protocol StatementColumnConvertible`

A type that can decode itself from the low-level C interface to SQLite results.

### Supporting Types

`protocol Cursor`

A type that supplies the values of some external resource, one at a time.

`protocol FetchRequest`

A type that fetches and decodes database rows.

## See Also

### Fundamentals

Open database connections to SQLite databases.

GRDB helps your app deal with Swift and SQLite concurrency.

Transactions and Savepoints

Precise transaction handling.

- SQL, Prepared Statements, Rows, and Values
- Overview
- SQL Support
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/concurrency

- GRDB
- Concurrency

API Collection

# Concurrency

GRDB helps your app deal with Swift and SQLite concurrency.

## Overview

If your app moves slow database jobs off the main thread, so that the user interface remains responsive, then this guide is for you. In the case of apps that share a database with other processes, such as an iOS app and its extensions, don’t miss the dedicated Sharing a Database guide after this one.

**In all cases, and first and foremost, follow the Concurrency Rules right from the start.**

The other chapters cover, with more details, the fundamentals of SQLite concurrency, and how GRDB makes it manageable from your Swift code.

## Concurrency Rules

**The two concurrency rules are strongly recommended practices.** They are all about SQLite, a robust and reliable database that takes great care of your data: don’t miss an opportunity to put it on your side!

#### Rule 1: Connect to any database file only once

Open one single `DatabaseQueue` or `DatabasePool` per database file, for the whole duration of your use of the database. Not for the duration of _each_ database access, but really for the duration of _all_ database accesses to this file.

- _Why does this rule exist?_ \- Since SQLite does not support parallel writes, each `DatabaseQueue` and `DatabasePool` makes sure application threads perform writes one by one, without overlap.

- _Practical advice_ \- An app that uses a single database will connect only once. A document-based app will connect each time a document is opened, and disconnect when the document is closed. See the demo apps in order to see how to setup a UIKit or SwiftUI application for a single database.

- _What if you do not follow this rule?_

- You will not be able to use the Database Observation features.

- You will see SQLite errors ( `SQLITE_BUSY`).

#### Rule 2: Mind your transactions

Database operations that are grouped in a transaction are guaranteed to be either fully saved on disk, or not at all. Read-only transactions guarantee a stable and immutable view of the database, and do not see changes performed by eventual concurrent writes.

In other words, transactions are the one and single tool that helps you enforce and rely on the invariants of your database (such as “all authors must have at least one book”).

**You are responsible**, in your Swift code, for delimiting transactions. You do so by grouping database accesses inside a pair of `{ db in ... }` brackets:

try dbQueue.write { db in
// Inside a transaction
}

try dbQueue.read { db
// Inside a transaction
}

Alternatively, you can open an explicit transaction or savepoint: see Transactions and Savepoints.

- _Why does this rule exist?_ \- Because GRDB and SQLite can not guess where to insert the transaction boundaries that protect the invariants of your database. This is your task. Transactions also avoid concurrency problems, as described in the Safe and Unsafe Database Accesses section below.

- _Practical advice_ \- Take the time to identify the invariants of your database. Some of them can be enforced in the database schema itself, such as “all books must have a non-empty title”, or “all books must have an author” (see The Database Schema). Some invariants can only be enforced by transactions, such as “all account credits must have a matching debit”, or “all authors must have at least one book”.

- _What if you do not follow this rule?_ \- You will see broken database invariants, at runtime, or when your apps wakes up after a crash. These bugs corrupt user data, and are very difficult to fix.

## Synchronous and Asynchronous Database Accesses

**You can access the database from any thread, in a synchronous or asynchronous way.**

➡️ **A sync access blocks the current thread** until the database operations are completed:

let playerCount = try dbQueue.read { db in
try Player.fetchCount(db)
}

try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

See `read(_:)` and `write(_:)`.

It is a programmer error to perform a sync access from any other database access (this restriction can be lifted: see Safe and Unsafe Database Accesses):

try dbQueue.write { db in
// Fatal Error: Database methods are not reentrant.
try dbQueue.write { db in ... }
}

🔀 **An async access does not block the current thread.** Instead, it notifies you when the database operations are completed. There are four ways to access the database asynchronously:

- **Swift concurrency** (async/await)

let playerCount = try await dbQueue.read { db in
try Player.fetchCount(db)
}

Note the identical method names: `read`, `write`. The async version is only available in async Swift functions.

The async database access methods honor task cancellation. Once an async Task is cancelled, reads and writes throw `CancellationError`, and any transaction is rollbacked.

See Swift Concurrency and GRDB for more information about GRDB and Swift 6.

- **Combine publishers**

For example:

let playerCountPublisher = dbQueue.readPublisher { db in
try Player.fetchCount(db)
}

See `readPublisher(receiveOn:value:)`, and `writePublisher(receiveOn:updates:)`.

Those publishers do not access the database until they are subscribed. They complete on the main dispatch queue by default.

- **RxSwift observables**

See the companion library RxGRDB.

- **Completion blocks**

See `asyncRead(_:)` and `asyncWrite(_:completion:)`.

During one async access, all individual database operations grouped inside (fetch, insert, etc.) are synchronous:

// One asynchronous access...
try await dbQueue.write { db in
// ... always performs synchronous database operations:
try Player(...).insert(db)
try Player(...).insert(db)
let players = try Player.fetchAll(db)
}

This is true for all async techniques.

This prevents the database operations from various concurrent accesses from being interleaved. For example, one access must not be able to issue a `COMMIT` statement in the middle of an unfinished concurrent write!

## Safe and Unsafe Database Accesses

**You will generally use the safe database access methods `read` and `write`.** In this context, “safe” means that a database access is concurrency-friendly, because GRDB provides the following guarantees:

#### Serialized Writes

**All writes performed by one `DatabaseQueue` or `DatabasePool` instance are serialized.**

This guarantee prevents `SQLITE_BUSY` errors during concurrent writes.

#### Write Transactions

**All writes are wrapped in a transaction.**

Concurrent reads can not see partial database updates (even reads performed by other processes).

#### Isolated Reads

**All reads are wrapped in a transaction.**

An isolated read sees a stable and immutable state of the database, and does not see changes performed by eventual concurrent writes (even writes performed by other processes). See Isolation In SQLite for more information.

#### Forbidden Writes

**Inside a read access, all attempts to write raise an error.**

This enforces the immutability of the database during a read.

#### Non-Reentrancy

**Database accesses methods are not reentrant.**

This reduces the opportunities for deadlocks, and fosters the clear transaction boundaries of Rule 2: Mind your transactions.

### Unsafe Database Accesses

Some applications need to relax this safety net, in order to achieve specific SQLite operations. In this case, replace `read` and `write` with one of the methods below:

- **Write outside of any transaction** (Lifted guarantee: Write Transactions)

See all `DatabaseWriter` methods with `WithoutTransaction` in their names.

- **Reentrant write, outside of any transaction** (Lifted guarantees: Write Transactions, Non-Reentrancy)

See `unsafeReentrantWrite(_:)`.

- **Read outside of any transaction** (Lifted guarantees: Isolated Reads, Forbidden Writes)

See all `DatabaseReader` methods with `unsafe` in their names.

- **Reentrant read, outside of any transaction** (Lifted guarantees: Isolated Reads, Forbidden Writes, Non-Reentrancy)

See `unsafeReentrantRead(_:)`.

Some concurrency guarantees can be restored at your convenience:

- The Write Transactions and Isolated Reads guarantees can be restored at any point, with an explicit transaction or savepoint. For example:

try dbQueue.writeWithoutTransaction { db in
try db.inTransaction { ... }
}

- The Forbidden Writes guarantee can only be lifted with `DatabaseQueue`. It can be restored with `PRAGMA query_only`.

## Differences between Database Queues and Pools

Despite the common guarantees and rules shared by database queues and pools, those two database accessors don’t have the same behavior.

`DatabaseQueue` opens a single database connection, and serializes all database accesses, reads, and writes. There is never more than one thread that uses the database. In the image below, we see how three threads can see the database as time passes:

`DatabasePool` manages a pool of several database connections, and allows concurrent reads and writes thanks to the WAL mode. A database pool serializes all writes (the Serialized Writes guarantee). Reads are isolated so that they don’t see changes performed by other threads (the Isolated Reads guarantee). This gives a very different picture:

See how, with database pools, two reads can see different database states at the same time. This may look scary! Please see the next chapter below for a relief.

## Concurrent Thinking

Despite the Differences between Database Queues and Pools, you can write robust code that works equally well with both `DatabaseQueue` and `DatabasePool`.

This allows your app to switch between queues and pools, at your convenience:

- The demo applications share the same database code for the on-disk pool that feeds the app, and the in-memory queue that feeds tests and SwiftUI previews. This makes sure tests and previews run fast, without any temporary file, with the same behavior as the app.

- Applications that perform slow write transactions (when saving a lot of data from a remote server, for example) may want to replace their queue with a pool so that the reads that feed their user interface can run in parallel.

All you need is a little “concurrent thinking”, based on those two basic facts:

- You are sure, when you perform a write access, that you deal with the latest database state on disk. This is enforced by SQLite, which simply can’t perform parallel writes, and by the Serialized Writes guarantee. Writes performed by other processes can trigger an `SQLITE_BUSY` `DatabaseError` that you can handle.

- Whenever you extract some data from a database access, immediately consider it as _stale_. It is stale, whether you use a `DatabaseQueue` or `DatabasePool`. It is stale because nothing prevents other application threads or processes from overwriting the value you have just fetched:

// or dbQueue.write, for that matter
let cookieCount = dbPool.read { db in
try Cookie.fetchCount(db)
}

// At this point, the number of cookies on disk
// may have already changed.
print("We have \(cookieCount) cookies left")

Does this mean you can’t rely on anything? Of course not:

- If you intend to display some database value on screen, use `ValueObservation`: it always eventually notifies the latest state of the database. Your application won’t display stale values for a long time: after the database has been changed on disk, the fresh value if fetched, and soon notified on the main thread where the screen can be updated.

- As said above, the moment of truth is the next write access!

## Advanced DatabasePool

`DatabasePool` is very concurrent, since all reads can run in parallel, and can even run during write operations. But writes are still serialized: at any given point in time, there is no more than a single thread that is writing into the database.

When your application modifies the database, and then reads some value that depends on those modifications, you may want to avoid blocking concurrent writes longer than necessary - especially when the read is slow:

let newPlayerCount = try dbPool.write { db in
// Increment the number of players
try Player(...).insert(db)

// Read the number of players. Concurrent writes are blocked :-(
return try Player.fetchCount(db)
}

🔀 The solution is `asyncConcurrentRead(_:)`. It must be called from within a write access, outside of any transaction:

try dbPool.writeWithoutTransaction { db in
// Increment the number of players
try db.inTransaction {
try Player(...).insert(db)
return .commit
}

// <- Not in a transaction here
dbPool.asyncConcurrentRead { dbResult in
do {
// Handle the new player count - guaranteed greater than zero
let db = try dbResult.get()
let newPlayerCount = try Player.fetchCount(db)
} catch {
// Handle error
}
}
}

The `asyncConcurrentRead(_:)` method blocks until it can guarantee its closure argument an isolated access to the database, in the exact state left by the last transaction. It then asynchronously executes the closure.

In the illustration below, the striped band shows the delay needed for the reading thread to acquire isolation. Until then, no other thread can write:

Types that conform to `TransactionObserver` can also use those methods in their `databaseDidCommit(_:)` method, in order to process database changes without blocking other threads that want to write into the database.

## Topics

### Database Connections with Concurrency Guarantees

`protocol DatabaseWriter`

A type that writes into an SQLite database.

`protocol DatabaseReader`

A type that reads from an SQLite database.

`protocol DatabaseSnapshotReader`

A type that sees an unchanging database content.

### Going Further

Swift Concurrency and GRDB

How to best integrate GRDB and Swift Concurrency

Sharing a Database

How to share an SQLite database between multiple processes • Recommendations for App Group containers, App Extensions, App Sandbox, and file coordination.

## See Also

### Fundamentals

Open database connections to SQLite databases.

SQL is the fundamental language for accessing SQLite databases.

Transactions and Savepoints

Precise transaction handling.

- Concurrency
- Overview
- Concurrency Rules
- Synchronous and Asynchronous Database Accesses
- Safe and Unsafe Database Accesses
- Unsafe Database Accesses
- Differences between Database Queues and Pools
- Concurrent Thinking
- Advanced DatabasePool
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/transactions

- GRDB
- Transactions and Savepoints

Article

# Transactions and Savepoints

Precise transaction handling.

## Transactions and Safety

**A transaction is a fundamental tool of SQLite** that guarantees data consistency as well as proper isolation between application threads and database connections. It is at the core of GRDB Concurrency guarantees.

To profit from database transactions, all you have to do is group related database statements in a single database access method such as `write(_:)` or `read(_:)`:

// BEGIN TRANSACTION
// INSERT INTO credit ...
// INSERT INTO debit ...
// COMMIT
try dbQueue.write { db in
try Credit(destinationAccount, amount).insert(db)
try Debit(sourceAccount, amount).insert(db)
}

// BEGIN TRANSACTION
// SELECT * FROM credit
// SELECT * FROM debit
// COMMIT
let (credits, debits) = try dbQueue.read { db in
let credits = try Credit.fetchAll(db)
let debits = try Debit.fetchAll(db)
return (credits, debits)
}

In the following sections we’ll explore how you can avoid transactions, and how to perform explicit transactions and savepoints.

## Database Accesses without Transactions

When needed, you can write outside of any transaction with `writeWithoutTransaction(_:)` (also named `inDatabase(_:)`, for `DatabaseQueue`):

// INSERT INTO credit ...
// INSERT INTO debit ...
try dbQueue.writeWithoutTransaction { db in
try Credit(destinationAccount, amount).insert(db)
try Debit(sourceAccount, amount).insert(db)
}

For reads, use `unsafeRead(_:)`:

// SELECT * FROM credit
// SELECT * FROM debit
let (credits, debits) = try dbPool.unsafeRead { db in
let credits = try Credit.fetchAll(db)
let debits = try Debit.fetchAll(db)
return (credits, debits)
}

Those method names, `writeWithoutTransaction` and `unsafeRead`, are longer and “scarier” than the regular `write` and `read` in order to draw your attention to the dangers of those unisolated accesses.

In our credit/debit example, a credit may be successfully inserted, but the debit insertion may fail, ending up with unbalanced accounts (oops).

// UNSAFE DATABASE INTEGRITY
try dbQueue.writeWithoutTransaction { db in // or dbPool.writeWithoutTransaction
try Credit(destinationAccount, amount).insert(db)
// 😬 May fail after credit was successfully written to disk:
try Debit(sourceAccount, amount).insert(db)
}

Transactions avoid this kind of bug.

`DatabasePool` concurrent reads can see an inconsistent state of the database:

// UNSAFE CONCURRENCY
try dbPool.writeWithoutTransaction { db in
try Credit(destinationAccount, amount).insert(db)
// <- 😬 Here a concurrent read sees a partial db update (unbalanced accounts)
try Debit(sourceAccount, amount).insert(db)
}

Transactions avoid this kind of bug, too.

Finally, reads performed outside of any transaction are not isolated from concurrent writes. It is possible to see unbalanced accounts, even though the invariant is never broken on disk:

// UNSAFE CONCURRENCY
let (credits, debits) = try dbPool.unsafeRead { db in
let credits = try Credit.fetchAll(db)
// <- 😬 Here a concurrent write can modify the balance before debits are fetched
let debits = try Debit.fetchAll(db)
return (credits, debits)
}

Yes, transactions also avoid this kind of bug.

## Explicit Transactions

To open explicit transactions, use `inTransaction()` or `writeInTransaction()`:

// BEGIN TRANSACTION
// INSERT INTO credit ...
// INSERT INTO debit ...
// COMMIT
try dbQueue.inTransaction { db in // or dbPool.writeInTransaction
try Credit(destinationAccount, amount).insert(db)
try Debit(sourceAccount, amount).insert(db)
return .commit
}

// BEGIN TRANSACTION
// INSERT INTO credit ...
// INSERT INTO debit ...
// COMMIT
try dbQueue.writeWithoutTransaction { db in
try db.inTransaction {
try Credit(destinationAccount, amount).insert(db)
try Debit(sourceAccount, amount).insert(db)
return .commit
}
}

If an error is thrown from the transaction block, the transaction is rollbacked and the error is rethrown by the transaction method. If the transaction closure returns `.rollback` instead of `.commit`, the transaction is also rollbacked, but no error is thrown.

Full manual transaction management is also possible:

try dbQueue.writeWithoutTransaction { db
try db.beginTransaction()
...
try db.commit()

try db.execute(sql: "BEGIN TRANSACTION")
...
try db.execute(sql: "ROLLBACK")
}

Make sure all transactions opened from a database access are committed or rollbacked from that same database access, because it is a programmer error to leave an opened transaction:

// fatal error: A transaction has been left
// opened at the end of a database access.
try dbQueue.writeWithoutTransaction { db in
try db.execute(sql: "BEGIN TRANSACTION")
// <- no commit or rollback
}

In particular, since commits may throw an error, make sure you perform a rollback when a commit fails.

This restriction can be left with the `allowsUnsafeTransactions` configuration flag.

It is possible to ask if a transaction is currently opened:

func myCriticalMethod(_ db: Database) throws {
precondition(db.isInsideTransaction, "This method requires a transaction")
try ...
}

Yet, there is a better option than checking for transactions. Critical database sections should use savepoints, described below:

func myCriticalMethod(_ db: Database) throws {
try db.inSavepoint {
// Here the database is guaranteed to be inside a transaction.
try ...
}
}

## Savepoints

**Statements grouped in a savepoint can be rollbacked without invalidating a whole transaction:**

try dbQueue.write { db in
// Makes sure both inserts succeed, or none:
try db.inSavepoint {
try Credit(destinationAccount, amount).insert(db)
try Debit(sourceAccount, amount).insert(db)
return .commit
}

// Other savepoints, etc...
}

If an error is thrown from the savepoint block, the savepoint is rollbacked and the error is rethrown by the `inSavepoint` method. If the savepoint closure returns `.rollback` instead of `.commit`, the savepoint is also rollbacked, but no error is thrown.

**Unlike transactions, savepoints can be nested.** They implicitly open a transaction if no one was opened when the savepoint begins. As such, they behave just like nested transactions. Yet the database changes are only written to disk when the outermost transaction is committed:

try dbQueue.writeWithoutTransaction { db in
try db.inSavepoint {
...
try db.inSavepoint {
...
return .commit
}
...
return .commit // Writes changes to disk
}
}

SQLite savepoints are more than nested transactions, though. For advanced uses, use SQLite savepoint documentation.

## Transaction Kinds

SQLite supports three kinds of transactions: deferred (the default), immediate, and exclusive.

By default, GRDB opens DEFERRED transaction for reads, and IMMEDIATE transactions for writes.

The transaction kind can be chosen for individual transaction:

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// BEGIN EXCLUSIVE TRANSACTION ...
try dbQueue.inTransaction(.exclusive) { db in ... }

## See Also

### Fundamentals

Open database connections to SQLite databases.

SQL is the fundamental language for accessing SQLite databases.

GRDB helps your app deal with Swift and SQLite concurrency.

- Transactions and Savepoints
- Transactions and Safety
- Database Accesses without Transactions
- Explicit Transactions
- Savepoints
- Transaction Kinds
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschema

- GRDB
- The Database Schema

# The Database Schema

Define or query the database schema.

## Overview

**GRDB supports all database schemas, and has no requirement.** Any existing SQLite database can be opened, and you are free to structure your new databases as you wish.

You perform modifications to the database schema with methods such as `create(table:options:body:)`, listed in Modifying the Database Schema. For example:

try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
t.column("score", .integer).notNull()
}

Most applications modify the database schema as new versions ship: it is recommended to wrap all schema changes in Migrations.

## Topics

### Define the database schema

How to modify the database schema

Database Schema Recommendations

Recommendations for an ideal integration of the database schema with GRDB

### Introspect the database schema

Get information about schema objects such as tables, columns, indexes, foreign keys, etc.

### Check the database schema

Perform integrity checks of the database content

## See Also

### Migrations and The Database Schema

Migrations allow you to evolve your database schema over time.

- The Database Schema
- Overview
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/migrations

- GRDB
- Migrations

API Collection

# Migrations

Migrations allow you to evolve your database schema over time.

## Overview

You can think of migrations as being ‘versions’ of the database. A database schema starts off in an empty state, and each migration adds or removes tables, columns, or entries.

GRDB can update the database schema along this timeline, bringing it from whatever point it is in the history to the latest version. When a user upgrades your application, only non-applied migrations are run.

You setup migrations in a `DatabaseMigrator` instance. For example:

var migrator = DatabaseMigrator()

// 1st migration
migrator.registerMigration("Create authors") { db in
try db.create(table: "author") { t in
t.autoIncrementedPrimaryKey("id")
t.column("creationDate", .datetime)
t.column("name", .text)
}
}

// 2nd migration
migrator.registerMigration("Add books and author.birthYear") { db in
try db.create(table: "book") { t in
t.autoIncrementedPrimaryKey("id")
t.belongsTo("author").notNull()
t.column("title", .text).notNull()
}

try db.alter(table: "author") { t in
t.add(column: "birthYear", .integer)
}
}

To migrate a database, open a connection (see Database Connections), and call the `migrate(_:)` method:

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// Migrate the database up to the latest version
try migrator.migrate(dbQueue)

You can also migrate a database up to a specific version (useful for testing):

try migrator.migrate(dbQueue, upTo: "v2")

// Migrations can only run forward:
try migrator.migrate(dbQueue, upTo: "v2")
try migrator.migrate(dbQueue, upTo: "v1")
// ^ fatal error: database is already migrated beyond migration "v1"

When several versions of your app are deployed in the wild, you may want to perform extra checks:

try dbQueue.read { db in
// Read-only apps or extensions may want to check if the database
// lacks expected migrations:
if try migrator.hasCompletedMigrations(db) == false {
// database too old
}

// Some apps may want to check if the database
// contains unknown (future) migrations:
if try migrator.hasBeenSuperseded(db) {
// database too new
}
}

**Each migration runs in a separate transaction.** Should one throw an error, its transaction is rollbacked, subsequent migrations do not run, and the error is eventually thrown by `migrate(_:)`.

**Migrations run with deferred foreign key checks.** This means that eventual foreign key violations are only checked at the end of the migration (and they make the migration fail). See Foreign Key Checks below for more information.

**The memory of applied migrations is stored in the database itself** (in a reserved table).

## Defining the Database Schema from a Migration

See The Database Schema for the methods that define the database schema. For example:

migrator.registerMigration("Create authors") { db in
try db.create(table: "author") { t in
t.autoIncrementedPrimaryKey("id")
t.column("creationDate", .datetime)
t.column("name", .text)
}
}

#### How to Rename a Foreign Key

When a migration **renames a foreign key**, make sure the migration runs with `.immediate` foreign key checks, in order to avoid database integrity problems:

// IMPORTANT: rename foreign keys with immediate foreign key checks.
migrator.registerMigration("Guilds", foreignKeyChecks: .immediate) { db in
try db.rename(table: "team", to: "guild")

try db.alter(table: "player") { t in
// Rename a foreign key
t.rename(column: "teamId", to: "guildId")
}
}

Note: migrations that run with `.immediate` foreign key checks can not be used to recreated database tables, as described below. When needed, define two migrations instead of one.

#### How to Recreate a Database Table

When you need to modify a table in a way that is not directly supported by SQLite, or not available on your target operating system, you will need to recreate the database table.

For example:

migrator.registerMigration("Add NOT NULL check on author.name") { db in
try db.create(table: "new_author") { t in
t.autoIncrementedPrimaryKey("id")
t.column("creationDate", .datetime)
t.column("name", .text).notNull()
}
try db.execute(sql: "INSERT INTO new_author SELECT * FROM author")
try db.drop(table: "author")
try db.rename(table: "new_author", to: "author")
}

The detailed sequence of operations for recreating a database table from a migration is:

1. When relevant, remember the format of all indexes, triggers, and views associated with table `X`. This information will be needed in steps 6 below. One way to do this is to run the following statement and examine the output in the console:

try db.dumpSQL("SELECT type, sql FROM sqlite_schema WHERE tbl_name='X'")

2. Construct a new table `new_X` that is in the desired revised format of table `X`. Make sure that the name `new_X` does not collide with any existing table name, of course.

try db.create(table: "new_X") { t in ... }

3. Transfer content from `X` into `new_X` using a statement like:

try db.execute(sql: "INSERT INTO new_X SELECT ... FROM X")

4. Drop the old table `X`:

try db.drop(table: "X")

5. Change the name of `new_X` to `X` using:

try db.rename(table: "new_X", to: "X")

6. When relevant, reconstruct indexes, triggers, and views associated with table `X`.

7. If any views refer to table `X` in a way that is affected by the schema change, then drop those views using `DROP VIEW` and recreate them with whatever changes are necessary to accommodate the schema change using `CREATE VIEW`.

## Good Practices for Defining Migrations

**A good migration is a migration that is never modified once it has shipped.**

It is much easier to control the schema of all databases deployed on users’ devices when migrations define a stable timeline of schema versions. For this reason, it is recommended that migrations define the database schema with **strings**:

migrator.registerMigration("Create authors") { db in
// RECOMMENDED
try db.create(table: "author") { t in
t.autoIncrementedPrimaryKey("id")
...
}

// NOT RECOMMENDED
try db.create(table: Author.databaseTableName) { t in
t.autoIncrementedPrimaryKey(Author.Columns.id.name)
...
}
}

In other words, migrations should talk to the database, only to the database, and use the database language. This makes sure the Swift code of any given migrations will never have to change in the future.

Migrations and the rest of the application code do not live at the same “moment”. Migrations describe the past states of the database, while the rest of the application code targets the latest one only. This difference is the reason why **migrations should not depend on application types.**

## The eraseDatabaseOnSchemaChange Option

A `DatabaseMigrator` can automatically wipe out the full database content, and recreate the whole database from scratch, if it detects that migrations have changed their definition.

Setting `eraseDatabaseOnSchemaChange` is useful during application development, as you are still designing migrations, and the schema changes often:

- A migration is removed, or renamed.

- A schema change is detected: any difference in the `sqlite_master` table, which contains the SQL used to create database tables, indexes, triggers, and views.

It is recommended that this option does not ship in the released application: hide it behind `#if DEBUG` as below.

#if DEBUG
var migrator = DatabaseMigrator()
// Speed up development by nuking the database when migrations change
migrator.eraseDatabaseOnSchemaChange = true
#endif

## Foreign Key Checks

By default, each migration temporarily disables foreign keys, and performs a full check of all foreign keys in the database before it is committed on disk.

When the database becomes very big, those checks may have a noticeable impact on migration performances. You’ll know this by profiling migrations, and looking for the time spent in the `checkForeignKeys` method.

You can make those migrations faster, but this requires a little care.

**Your first mitigation technique is immediate foreign key checks.**

When you register a migration with `.immediate` foreign key checks, the migration does not temporarily disable foreign keys, and does not need to perform a deferred full check of all foreign keys in the database:

migrator.registerMigration("Fast migration", foreignKeyChecks: .immediate) { db in ... }

Such a migration is faster, and it still guarantees database integrity. But it must only execute schema alterations directly supported by SQLite. Migrations that recreate tables as described in Defining the Database Schema from a Migration **must not** run with immediate foreign keys checks. You’ll need to use the second mitigation technique:

**Your second mitigation technique is to disable deferred foreign key checks.**

You can ask the migrator to stop performing foreign key checks for all newly registered migrations:

migrator = migrator.disablingDeferredForeignKeyChecks()

Migrations become unchecked by default, and run faster. But your app becomes responsible for preventing foreign key violations from being committed to disk:

migrator = migrator.disablingDeferredForeignKeyChecks()
migrator.registerMigration("Fast but unchecked migration") { db in ... }

To prevent a migration from committing foreign key violations on disk, you can:

- Register the migration with immediate foreign key checks, as long as it does not recreate tables as described in Defining the Database Schema from a Migration:

migrator = migrator.disablingDeferredForeignKeyChecks()
migrator.registerMigration("Fast and checked migration", foreignKeyChecks: .immediate) { db in ... }

- Perform foreign key checks on some tables only, before the migration is committed on disk:

migrator = migrator.disablingDeferredForeignKeyChecks()
migrator.registerMigration("Partially checked") { db in
...

// Throws an error and stops migrations if there exists a
// foreign key violation in the 'book' table.
try db.checkForeignKeys(in: "book")
}

As in the above example, check for foreign key violations with the `checkForeignKeys()` and `checkForeignKeys(in:in:)` methods. They throw a nicely detailed `DatabaseError` that contains a lot of debugging information:

// SQLite error 19: FOREIGN KEY constraint violation - from book(authorId) to author(id),
// in [id:1 authorId:2 name:"Moby-Dick"]
try db.checkForeignKeys(in: "book")

Alternatively, you can deal with each individual violation by iterating a cursor of `ForeignKeyViolation`.

## Topics

### DatabaseMigrator

`struct DatabaseMigrator`

A `DatabaseMigrator` registers and applies database migrations.

## See Also

### Migrations and The Database Schema

Define or query the database schema.

- Migrations
- Overview
- Defining the Database Schema from a Migration
- Good Practices for Defining Migrations
- The eraseDatabaseOnSchemaChange Option
- Foreign Key Checks
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/queryinterface

- GRDB
- Records and the Query Interface

API Collection

# Records and the Query Interface

Record types and the query interface build SQL queries for you.

## Overview

For an overview, see Records, and The Query Interface.

## Topics

### Records Protocols

`protocol EncodableRecord`

A type that can encode itself in a database row.

`protocol FetchableRecord`

A type that can decode itself from a database row.

`protocol MutablePersistableRecord`

A type that can be persisted in the database, and mutates on insertion.

`protocol PersistableRecord`

A type that can be persisted in the database.

`protocol TableRecord`

A type that builds database queries with the Swift language instead of SQL.

### Expressions

`struct Column`

A column in a database table.

`struct JSONColumn`

A JSON column in a database table.

`struct SQLExpression`

An SQL expression.

### Requests

`struct CommonTableExpression`

A common table expression that can be used with the GRDB query interface.

`struct QueryInterfaceRequest`

A request that builds SQL queries with Swift.

`struct Table`

A `Table` builds database queries with the Swift language instead of SQL.

### Associations

`protocol Association`

A type that defines a connection between two tables.

### Errors

`enum RecordError`

A record error.

`typealias PersistenceError` Deprecated

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

### Legacy Types

`class Record`

A base class for types that can be fetched and persisted in the database.

## See Also

### Records and the Query Interface

Recommended Practices for Designing Record Types

Leverage the best of record types and associations.

Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

Single-Row Tables

The setup for database tables that should contain a single row.

- Records and the Query Interface
- Overview
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recordrecommendedpractices

- GRDB
- Recommended Practices for Designing Record Types

Article

# Recommended Practices for Designing Record Types

Leverage the best of record types and associations.

## Overview

GRDB sits right between low-level SQLite wrappers, and high-level ORMs like Core Data, so you may face questions when designing the model layer of your application.

This is the topic of this article. Examples will be illustrated with a simple library database made of books and their authors.

## Trust SQLite More Than Yourself

Let’s put things in the right order. An SQLite database stored on a user’s device is more important than the Swift code that accesses it. When a user installs a new version of an application, only the database stored on the user’s device remains the same. But all the Swift code may have changed.

This is why it is recommended to define a **robust database schema** even before playing with record types.

This is important because SQLite is very robust, whereas we developers write bugs. The more responsibility we give to SQLite, the less code we have to write, and the fewer defects we will ship on our users’ devices, affecting their precious data.

For example, if we were to define Migrations that configure a database made of books and their authors, we could write:

var migrator = DatabaseMigrator()

migrator.registerMigration("createLibrary") { db in
try db.create(table: "author") { t in // (1)
t.autoIncrementedPrimaryKey("id") // (2)
t.column("name", .text).notNull() // (3)
t.column("countryCode", .text) // (4)
}

try db.create(table: "book") { t in
t.autoIncrementedPrimaryKey("id")
t.column("title", .text).notNull() // (5)
t.belongsTo("author", onDelete: .cascade) // (6)
.notNull() // (7)
}
}

try migrator.migrate(dbQueue)

1. Our database tables follow the Database Schema Recommendations: table names are English, singular, and camelCased. They look like Swift identifiers: `author`, `book`, `postalAddress`, `httpRequest`.

2. Each author has a unique id.

3. An author must have a name.

4. The country of an author is not always known.

5. A book must have a title.

6. The `book.authorId` column is used to link a book to the author it belongs to. This column is indexed in order to ease the selection of an author’s books. A foreign key is defined from `book.authorId` column to `authors.id`, so that SQLite guarantees that no book refers to a missing author. The `onDelete: .cascade` option has SQLite automatically delete all of an author’s books when that author is deleted. See Foreign Key Actions for more information.

7. The `book.authorId` column is not null so that SQLite guarantees that all books have an author.

Thanks to this database schema, the application will always process _consistent data_, no matter how wrong the Swift code can get. Even after a hard crash, all books will have an author, a non-nil title, etc.

## Record Types

### Persistable Record Types are Responsible for Their Tables

**Define one record type per database table.** This record type will be responsible for writing in this table.

**Let’s start from regular structs** whose properties match the columns in their database table. They conform to the standard `Codable` protocol so that we don’t have to write the methods that convert to and from raw database rows.

struct Author: Codable {
var id: Int64?
var name: String
var countryCode: String?
}

struct Book: Codable {
var id: Int64?
var authorId: Int64
var title: String
}

**We add database powers to our types with record protocols.**

The `author` and `book` tables have an auto-incremented id. We want inserted records to learn about their id after a successful insertion. That’s why we have them conform to the `MutablePersistableRecord` protocol, and implement `didInsert(_:)`. Other kinds of record types would just use `PersistableRecord`, and ignore `didInsert`.

On the reading side, we use `FetchableRecord`, the protocol that can decode database rows.

This gives:

// Add Database access
extension Author: FetchableRecord, MutablePersistableRecord {
// Update auto-incremented id upon successful insertion
mutating func didInsert(_ inserted: InsertionSuccess) {
id = inserted.rowID
}
}

extension Book: FetchableRecord, MutablePersistableRecord {
// Update auto-incremented id upon successful insertion
mutating func didInsert(_ inserted: InsertionSuccess) {
id = inserted.rowID
}
}

That’s it. The `Author` type can read and write in the `author` database table. `Book` as well, in `book`:

try dbQueue.write { db in
// Insert and set author's id
var author = Author(name: "Herman Melville", countryCode: "US")
try author.insert(db)

// Insert and set book's id
var book = Book(authorId: author.id!, title: "Moby-Dick")
try book.insert(db)
}

let books = try dbQueue.read { db in
try Book.fetchAll(db)
}

### Record Types Hide Intimate Database Details

In the previous sample codes, the `Book` and `Author` structs have one property per database column, and their types are natively supported by SQLite ( `String`, `Int`, etc.)

But it happens that raw database column names, or raw column types, are not a very good fit for the application.

When this happens, it’s time to **distinguish the Swift and database representations**. Record types are the dedicated place where raw database values can be transformed into Swift types that are well-suited for the rest of the application.

Let’s look at three examples.

#### First Example: Enums

Authors write books, and more specifically novels, poems, essays, or theatre plays. Let’s add a `kind` column in the database. We decide that a book kind is represented as a string (“novel”, “essay”, etc.) in the database:

try db.create(table: "book") { t in
...
t.column("kind", .text).notNull()
}

In Swift, it is not a good practice to use `String` for the type of the `kind` property. We prefer an enum instead:

struct Book: Codable {
enum Kind: String, Codable {
case essay, novel, poetry, theater
}
var id: Int64?
var authorId: Int64
var title: String
var kind: Kind
}

Thanks to its enum property, the `Book` record prevents invalid book kinds from being stored into the database.

In order to use `Book.Kind` in database requests for books (see Record Requests below), we add the `DatabaseValueConvertible` conformance to `Book.Kind`:

extension Book.Kind: DatabaseValueConvertible { }

// Fetch all novels
let novels = try dbQueue.read { db in
try Book.filter { $0.kind == Book.Kind.novel }.fetchAll(db)
}

#### Second Example: GPS Coordinates

GPS coordinates can be stored in two distinct `latitude` and `longitude` columns. But the standard way to deal with such coordinate is a single `CLLocationCoordinate2D` struct.

When this happens, keep column properties private, and provide sensible accessors instead:

try db.create(table: "place") { t in
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
t.column("latitude", .double).notNull()
t.column("longitude", .double).notNull()
}

struct Place: Codable {
var id: Int64?
var name: String
private var latitude: CLLocationDegrees
private var longitude: CLLocationDegrees

var coordinate: CLLocationCoordinate2D {
get {
CLLocationCoordinate2D(
latitude: latitude,
longitude: longitude)
}
set {
latitude = newValue.latitude
longitude = newValue.longitude
}
}
}

Generally speaking, private properties make it possible to hide raw columns from the rest of the application. The next example shows another application of this technique.

#### Third Example: Money Amounts

Before storing money amounts in an SQLite database, take care that floating-point numbers are never a good fit.

SQLite only supports two kinds of numbers: integers and doubles, so we’ll store amounts as integers. $12.00 will be represented by 1200, a quantity of cents. This allows SQLite to compute exact sums of price, for example.

On the other side, an amount of cents is not very practical for the rest of the Swift application. The `Decimal` type looks like a better fit.

That’s why the `Product` record type has a `price: Decimal` property, backed by a `priceCents` integer column:

try db.create(table: "product") { t in
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
t.column("priceCents", .integer).notNull()
}

struct Product: Codable {
var id: Int64?
var name: String
private var priceCents: Int

var price: Decimal {
get {
Decimal(priceCents) / 100
}
set {
priceCents = Self.cents(for: newValue)
}
}

Int(Double(truncating: NSDecimalNumber(decimal: value * 100)))
}
}

## Record Requests

Once we have record types that are able to read and write in the database, we’d like to perform database requests of such records.

### Columns

Requests that filter or sort records are defined with **columns**, defined in a dedicated enumeration, with the name `Columns`, nested inside the record type. When the record type conforms to `Codable`, columns can be derived from the `CodingKeys` enum:

// HOW TO define columns for a Codable record
extension Author {
enum Columns {
static let id = Column(CodingKeys.id)
static let name = Column(CodingKeys.name)
static let countryCode = Column(CodingKeys.countryCode)
}
}

For non-Codable record types, declare columns with their names:

// HOW TO define columns for a non-Codable record
extension Author {
enum Columns {
static let id = Column("id")
static let name = Column("name")
static let countryCode = Column("countryCode")
}
}

From those columns it is possible to define requests of type `QueryInterfaceRequest`:

try dbQueue.read { db in
// Fetch all authors, ordered by name,
// in a localized case-insensitive fashion
let sortedAuthors: [Author] = try Author.all()
.order { $0.name.collating(.localizedCaseInsensitiveCompare) }
.fetchAll(db)

// Count French authors
let frenchAuthorCount: Int = try Author.all()
.filter { $0.countryCode == "FR" }
.fetchCount(db)
}

### Turn Commonly-Used Requests into Methods

An application can define reusable request methods that extend the built-in GRDB apis. Those methods avoid code repetition, ease refactoring, and foster testability.

Define those methods in extensions of the `DerivableRequest` protocol, as below:

// Author requests

/// Order authors by name, in a localized case-insensitive fashion

order { $0.name.collating(.localizedCaseInsensitiveCompare) }
}

/// Filters authors from a country

filter { $0.countryCode == countryCode }
}
}

// Book requests

/// Order books by title, in a localized case-insensitive fashion

order { $0.title.collating(.localizedCaseInsensitiveCompare) }
}

/// Filters books by kind

filter { $0.kind == kind }
}
}

Those methods define a fluent and legible api that encapsulates intimate database details:

try dbQueue.read { db in
let sortedSpanishAuthors: [Author] = try Author.all()
.filter(countryCode: "ES")
.orderByName()
.fetchAll(db)

let novelCount: Int = try Book.all()
.filter(kind: .novel)
.fetchCount(db)
}

Extensions to the `DerivableRequest` protocol can not change the type of requests. They remain requests of the base record. To define requests of another type, use an extension to `QueryInterfaceRequest`, as in the example below:

// Selects authors' name

select(\.name)
}
}

// The names of Japanese authors

.filter(countryCode: "JP")
.selectName()
.fetchSet(db)

## Associations

Associations help navigating from authors to their books and vice versa. Because the `book` table has an `authorId` column, we say that each book **belongs to** its author, and each author **has many** books:

extension Book {
static let author = belongsTo(Author.self)
}

extension Author {
static let books = hasMany(Book.self)
}

With associations, you can fetch a book’s author, or an author’s books:

// Fetch all novels from an author
try dbQueue.read { db in
let author: Author = ...
let novels: [Book] = try author.request(for: Author.books)
.filter(kind: .novel)
.orderByTitle()
.fetchAll(db)
}

Associations also make it possible to define more convenience request methods:

/// Filters books from a country

// Books do not have any country column. But their author has one!
// Return books that can be joined to an author from this country:
joining(required: Book.author.filter(countryCode: countryCode))
}
}

// Fetch all Italian novels
try dbQueue.read { db in
let italianNovels: [Book] = try Book.all()
.filter(kind: .novel)
.filter(authorCountryCode: "IT")
.fetchAll(db)
}

With associations, you can also process graphs of authors and books, as described in the next section.

### How to Model Graphs of Objects

Since the beginning of this article, the `Book` and `Author` are independent structs that don’t know each other. The only “meeting point” is the `Book.authorId` property.

Record types don’t know each other on purpose: one does not need to know the author of a book when it’s time to update the title of a book, for example.

When an application wants to process authors and books together, it defines dedicated types that model the desired view on the graph of related objects. For example:

// Fetch all authors along with their number of books
struct AuthorInfo: Decodable, FetchableRecord {
var author: Author
var bookCount: Int
}
let authorInfos: [AuthorInfo] = try dbQueue.read { db in
try Author
.annotated(with: Author.books.count)
.asRequest(of: AuthorInfo.self)
.fetchAll(db)
}

// Fetch the literary careers of German authors, sorted by name
struct LiteraryCareer: Codable, FetchableRecord {
var author: Author
var books: [Book]
}
let careers: [LiteraryCareer] = try dbQueue.read { db in
try Author
.filter(countryCode: "DE")
.orderByName()
.including(all: Author.books)
.asRequest(of: LiteraryCareer.self)
.fetchAll(db)
}

// Fetch all Colombian books and their authors
struct Authorship: Decodable, FetchableRecord {
var book: Book
var author: Author
}
let authorships: [Authorship] = try dbQueue.read { db in
try Book.all()
.including(required: Book.author.filter(countryCode: "CO"))
.asRequest(of: Authorship.self)
.fetchAll(db)

// Equivalent alternative
try Book.all()
.filter(authorCountryCode: "CO")
.including(required: Book.author)
.asRequest(of: Authorship.self)
.fetchAll(db)
}

In the above sample codes, requests that fetch values from several tables are decoded into additional record types: `AuthorInfo`, `LiteraryCareer`, and `Authorship`.

Those record type conform to both `Decodable` and `FetchableRecord`, so that they can feed from database rows. They do not provide any persistence methods, though. **All database writes are performed from persistable record instances** (of type `Author` or `Book`).

For more information about associations, see the Associations guide.

### Lazy and Eager Loading: Comparison with Other Database Libraries

The additional record types described in the previous section may look superfluous. Some other database libraries are able to navigate in graphs of records without additional types.

For example, Core Data and Ruby’s Active Record use **lazy loading**. This means that relationships are lazily fetched on demand:

# Lazy loading with Active Record
author = Author.first # Fetch first author
puts author.name
author.books.each do |book| # Lazily fetch books on demand
puts book.title
end

**GRDB does not perform lazy loading.** In a GUI application, lazy loading can not be achieved without record management (as in Core Data), which in turn comes with non-trivial pain points for developers regarding concurrency. Instead of lazy loading, the library provides the tooling needed to fetch data, even complex graphs, in an isolated fashion, so that fetched values accurately represent the database content, and all database invariants are preserved. See the Concurrency guide for more information.

Vapor Fluent uses **eager loading**, which means that relationships are only fetched if explicitly requested:

// Eager loading with Fluent
let query = Author.query(on: db)
.with(\.$books) // <- Explicit request for books
.first()

// Fetch first author and its books in one stroke
if let author = query.get() {
print(author.name)
for book in author.books { print(book.title) }
}

One must take care of fetching relationships, though, or Fluent raises a fatal error:

// Oops, the books relation is not explicitly requested
let query = Author.query(on: db).first()
if let author = query.get() {
// fatal error: Children relation not eager loaded.
for book in author.books { print(book.title) }
}

**GRDB supports eager loading**. The difference with Fluent is that the relationships are modelled in a dedicated record type that provides runtime safety:

// Eager loading with GRDB
struct LiteraryCareer: Codable, FetchableRecord {
var author: Author
var books: [Book]
}

let request = Author.all()
.including(all: Author.books) // <- Explicit request for books
.asRequest(of: LiteraryCareer.self)

// Fetch first author and its books in one stroke
if let career = try request.fetchOne(db) {
print(career.author.name)
for book in career.books { print(book.title) }
}

## See Also

### Records and the Query Interface

Record types and the query interface build SQL queries for you.

Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

Single-Row Tables

The setup for database tables that should contain a single row.

- Recommended Practices for Designing Record Types
- Overview
- Trust SQLite More Than Yourself
- Record Types
- Persistable Record Types are Responsible for Their Tables
- Record Types Hide Intimate Database Details
- Record Requests
- Columns
- Turn Commonly-Used Requests into Methods
- Associations
- How to Model Graphs of Objects
- Lazy and Eager Loading: Comparison with Other Database Libraries
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recordtimestamps

- GRDB
- Record Timestamps and Transaction Date

Article

# Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

## Overview

Some applications want to record creation and modification dates of database records. This article provides some advice and sample code that you can adapt for your specific needs.

We’ll start from this table and record type:

try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("creationDate", .datetime).notNull()
t.column("modificationDate", .datetime).notNull()
t.column("name", .text).notNull()
t.column("score", .integer).notNull()
}

struct Player {
var id: Int64?
var creationDate: Date?
var modificationDate: Date?
var name: String
var score: Int
}

See how the table has non-null dates, while the record has optional dates.

This is because we intend, in this article, to timestamp actual database operations. The `creationDate` property is the date of database insertion, and `modificationDate` is the date of last modification in the database. A new `Player` instance has no meaningful timestamp until it is saved, and this absence of information is represented with `nil`:

// A new player has no timestamps.
var player = Player(id: nil, name: "Arthur", score: 1000)
player.id // nil, because never saved
player.creationDate // nil, because never saved
player.modificationDate // nil, because never saved

// After insertion, the player has timestamps.
try dbQueue.write { db in
try player.insert(db)
}
player.id // not nil
player.creationDate // not nil
player.modificationDate // not nil

In the rest of the article, we’ll address insertion first, then updates, and see a way to avoid those optional timestamps. The article ends with a sample protocol that your app may adapt and reuse.

- Insertion Timestamp

- Modification Timestamp

- Dealing with Optional Timestamps

- Sample code: TimestampedRecord

## Insertion Timestamp

On insertion, the `Player` record should get fresh `creationDate` and `modificationDate`. The `MutablePersistableRecord` protocol provides the necessary tooling, with the `willInsert(_:)` persistence callback. Before insertion, the record sets both its `creationDate` and `modificationDate`:

extension Player: Encodable, MutablePersistableRecord {
/// Sets both `creationDate` and `modificationDate` to the
/// transaction date, if they are not set yet.
mutating func willInsert(_ db: Database) throws {
if creationDate == nil {
creationDate = try db.transactionDate
}
if modificationDate == nil {
modificationDate = try db.transactionDate
}
}

/// Update auto-incremented id upon successful insertion
mutating func didInsert(_ inserted: InsertionSuccess) {
id = inserted.rowID
}
}

try dbQueue.write { db in
// An inserted record has both a creation and a modification date.
var player = Player(name: "Arthur", score: 1000)
try player.insert(db)
player.creationDate // not nil
player.modificationDate // not nil
}

The `willInsert` callback uses the `transactionDate` instead of `Date()`. This has two advantages:

- Within a write transaction, all inserted players get the same timestamp:

// All players have the same timestamp.
try dbQueue.write { db in
for var player in players {
try player.insert(db)
}
}

- The transaction date can be configured with `transactionClock`, so that your tests and previews can control the date.

## Modification Timestamp

Let’s now deal with updates. The `update` persistence method won’t automatically bump the timestamp as the `insert` method does. We have to explicitly deal with the modification date:

// Increment the player score (two different ways).
try dbQueue.write { db in
var player: Player

// Update all columns
player.score += 1
player.modificationDate = try db.transactionDate
try player.update(db)

// Alternatively, update only the modified columns
try player.updateChanges(db) {
$0.score += 1
$0.modificationDate = try db.transactionDate
}
}

Again, we use `transactionDate`, so that all modified players get the same timestamp within a given write transaction.

## Dealing with Optional Timestamps

When you fetch timestamped records from the database, it may be inconvenient to deal with optional dates, even though the database columns are guaranteed to be not null:

let player = try dbQueue.read { db
try Player.find(db, key: 1)
}
player.creationDate // optional 😕
player.modificationDate // optional 😕

A possible technique is to define two record types: one that deals with players in general (optional timestamps), and one that only deals with persisted players (non-optional dates):

/// `Player` deals with unsaved players
struct Player {
var id: Int64? // optional
var creationDate: Date? // optional
var modificationDate: Date? // optional
var name: String
var score: Int
}

extension Player: Encodable, MutablePersistableRecord {
/// Updates auto-incremented id upon successful insertion
mutating func didInsert(_ inserted: InsertionSuccess) {
id = inserted.rowID
}

/// Sets both `creationDate` and `modificationDate` to the
/// transaction date, if they are not set yet.
mutating func willInsert(_ db: Database) throws {
if creationDate == nil {
creationDate = try db.transactionDate
}
if modificationDate == nil {
modificationDate = try db.transactionDate
}
}
}

/// `PersistedPlayer` deals with persisted players
struct PersistedPlayer: Identifiable {
let id: Int64 // not optional
let creationDate: Date // not optional
var modificationDate: Date // not optional
var name: String
var score: Int
}

extension PersistedPlayer: Codable, FetchableRecord, PersistableRecord {
static var databaseTableName: String { "player" }
}

Usage:

// Fetch
try dbQueue.read { db
let persistedPlayer = try PersistedPlayer.find(db, id: 1)
persistedPlayer.creationDate // not optional
persistedPlayer.modificationDate // not optional
}

// Insert
try dbQueue.write { db in
var player = Player(id: nil, name: "Arthur", score: 1000)
player.id // nil
player.creationDate // nil
player.modificationDate // nil

let persistedPlayer = try player.insertAndFetch(db, as: PersistedPlayer.self)
persistedPlayer.id // not optional
persistedPlayer.creationDate // not optional
persistedPlayer.modificationDate // not optional
}

See `insertAndFetch(_:onConflict:as:)` and related methods for more information.

## Sample code: TimestampedRecord

This section provides a sample protocol for records that track their creation and modification dates.

You can copy it in your application, or use it as an inspiration. Not all apps have the same needs regarding timestamps!

`TimestampedRecord` provides the following features and methods:

- Use it as a replacement for `MutablePersistableRecord` (even if your record does not use an auto-incremented primary key):

// The base Player type
struct Player {
var id: Int64?
var creationDate: Date?
var modificationDate: Date?
var name: String
var score: Int
}

// Add database powers (read, write, timestamps)
extension Player: Codable, TimestampedRecord, FetchableRecord {
/// Update auto-incremented id upon successful insertion
mutating func didInsert(_ inserted: InsertionSuccess) {
id = inserted.rowID
}
}

- Timestamps are set on insertion:

- `updateWithTimestamp()` behaves like `update(_:onConflict:)`, but it also bumps the modification date.

// Bump the modification date and update all columns in the database.
player.score += 1
try player.updateWithTimestamp(db)

- `updateChangesWithTimestamp()` behaves like `updateChanges(_:onConflict:modify:)`, but it also bumps the modification date if the record is modified.

// Only bump the modification date if record is changed, and only
// update the changed columns.
try player.updateChangesWithTimestamp(db) {
$0.score = 1000
}

// Prefer updateChanges() if the modification date should always be
// updated, even if other columns are not changed.
try player.updateChanges(db) {
$0.score = 1000
$0.modificationDate = try db.transactionDate
}

- `touch()` only updates the modification date in the database, just like the `touch` unix command.

// Only update the modification date in the database.
try player.touch(db)

- There is no `TimestampedRecord.saveWithTimestamp()` method that would insert or update, like `save(_:onConflict:)`. You are encouraged to write instead (and maybe extend your version of `TimestampedRecord` so that it supports this pattern):

extension Player {
/// If the player has a non-nil primary key and a matching row in
/// the database, the player is updated. Otherwise, it is inserted.
mutating func saveWithTimestamp(_ db: Database) throws {
// Test the presence of id first, so that we don't perform an
// update that would surely throw RecordError.recordNotFound.
if id == nil {
try insert(db)
} else {
do {
try updateWithTimestamp(db)
} catch RecordError.recordNotFound {
// Primary key is set, but no row was updated.
try insert(db)
}
}
}
}

The full implementation of `TimestampedRecord` follows:

/// A record type that tracks its creation and modification dates. See

var creationDate: Date? { get set }
var modificationDate: Date? { get set }
}

extension TimestampedRecord {
/// By default, `TimestampedRecord` types set `creationDate` and
/// `modificationDate` to the transaction date, if they are nil,
/// before insertion.
///
/// `TimestampedRecord` types that customize the `willInsert`
/// persistence callback should call `initializeTimestamps` from
/// their implementation.
mutating func willInsert(_ db: Database) throws {
try initializeTimestamps(db)
}

/// Sets `creationDate` and `modificationDate` to the transaction date,
/// if they are nil.
///
/// It is called automatically before insertion, if your type does not
/// customize the `willInsert` persistence callback. If you customize
/// this callback, call `initializeTimestamps` from your implementation.
mutating func initializeTimestamps(_ db: Database) throws {
if creationDate == nil {
creationDate = try db.transactionDate
}
if modificationDate == nil {
modificationDate = try db.transactionDate
}
}

/// Sets `modificationDate`, and executes an `UPDATE` statement
/// on all columns.
///
/// - parameter modificationDate: The modification date. If nil, the
/// transaction date is used.
mutating func updateWithTimestamp(_ db: Database, modificationDate: Date? = nil) throws {
self.modificationDate = try modificationDate ?? db.transactionDate
try update(db)
}

/// Modifies the record according to the provided `modify` closure, and,
/// if and only if the record was modified, sets `modificationDate` and
/// executes an `UPDATE` statement that updates the modified columns.
///
/// For example:
///
/// ```swift
/// try dbQueue.write { db in
/// var player = Player.find(db, id: 1)
/// let modified = try player.updateChangesWithTimestamp(db) {
/// $0.score = 1000
/// }
/// if modified {
/// print("player was modified")
/// } else {
/// print("player was not modified")
/// }
/// }
/// ```
///
/// - parameters:
/// - db: A database connection.
/// - modificationDate: The modification date. If nil, the
/// transaction date is used.
/// - modify: A closure that modifies the record.
/// - returns: Whether the record was changed and updated.
@discardableResult
mutating func updateChangesWithTimestamp(
_ db: Database,
modificationDate: Date? = nil,

{
// Grab the changes performed by `modify`
let initialChanges = try databaseChanges(modify: modify)
if initialChanges.isEmpty {
return false
}

// Update modification date and grab its column name
let dateChanges = try databaseChanges(modify: {
$0.modificationDate = try modificationDate ?? db.transactionDate
})

// Update the modified columns
let modifiedColumns = Set(initialChanges.keys).union(dateChanges.keys)
try update(db, columns: modifiedColumns)
return true
}

/// Sets `modificationDate`, and executes an `UPDATE` statement that
/// updates the `modificationDate` column, if and only if the record
/// was modified.
///
/// - parameter modificationDate: The modification date. If nil, the
/// transaction date is used.
mutating func touch(_ db: Database, modificationDate: Date? = nil) throws {
try updateChanges(db) {
$0.modificationDate = try modificationDate ?? db.transactionDate
}
}
}

## See Also

### Records and the Query Interface

Record types and the query interface build SQL queries for you.

Recommended Practices for Designing Record Types

Leverage the best of record types and associations.

Single-Row Tables

The setup for database tables that should contain a single row.

- Record Timestamps and Transaction Date
- Overview
- Insertion Timestamp
- Modification Timestamp
- Dealing with Optional Timestamps
- Sample code: TimestampedRecord
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/singlerowtables

- GRDB
- Single-Row Tables

Article

# Single-Row Tables

The setup for database tables that should contain a single row.

## Overview

Database tables that contain a single row can store configuration values, user preferences, and generally some global application state.

They are a suitable alternative to `UserDefaults` in some applications, especially when configuration refers to values found in other database tables, and database integrity is a concern.

A possible way to store such configuration is a table of key-value pairs: two columns, and one row for each configuration value. This technique works, but it has a few drawbacks: one has to deal with the various types of configuration values (strings, integers, dates, etc), and it is not possible to define foreign keys. This is why we won’t explore key-value tables.

In this guide, we’ll implement a single-row table, with recommendations on the database schema, migrations, and the design of a Swift API for accessing the configuration values. The schema will define one column for each configuration value, because we aim at being able to deal with foreign keys and references to other tables. You may prefer storing configuration values in a single JSON column. In this case, take inspiration from this guide, as well as JSON Support.

We will also aim at providing a default value for a given configuration, even when it is not stored on disk yet. This is a feature similar to `UserDefaults.register(defaults:)`.

## The Single-Row Table

As always with SQLite, everything starts at the level of the database schema. When we put the database engine on our side, we have to write less code, and this helps shipping less bugs.

We want to instruct SQLite that our table must never contain more than one row. We will never have to wonder what to do if we were unlucky enough to find two rows with conflicting values in this table.

SQLite is not able to guarantee that the table is never empty, so we have to deal with two cases: either the table is empty, or it contains one row.

Those two cases can create a nagging question for the application. By default, inserts fail when the row already exists, and updates fail when the table is empty. In order to avoid those errors, we will have the app deal with updates in the The Single-Row Record section below. Right now, we instruct SQLite to just replace the eventual existing row in case of conflicting inserts.

migrator.registerMigration("appConfiguration") { db in
// CREATE TABLE appConfiguration (
// id INTEGER PRIMARY KEY ON CONFLICT REPLACE CHECK (id = 1),
// storedFlag BOOLEAN,
// ...)
try db.create(table: "appConfiguration") { t in
// Single row guarantee: have inserts replace the existing row,
// and make sure the id column is always 1.
t.primaryKey("id", .integer, onConflict: .replace)
.check { $0 == 1 }

// The configuration columns
t.column("storedFlag", .boolean)
// ... other columns
}
}

Note how the database table is defined in a migration. That’s because most apps evolve, and need to add other configuration columns eventually. See Migrations for more information.

We have defined a `storedFlag` column that can be NULL. That may be surprising, because optional booleans are usually a bad idea! But we can deal with this NULL at runtime, and nullable columns have a few advantages:

- NULL means that the application user had not made a choice yet. When `storedFlag` is NULL, the app can use a default value, such as `true`.

- As application evolves, application will need to add new configuration columns. It is not always possible to provide a sensible default value for these new columns, at the moment the table is modified. On the other side, it is generally possible to deal with those NULL values at runtime.

Despite those arguments, some apps absolutely require a value. In this case, don’t weaken the application logic and make sure the database can’t store a NULL value:

// DO NOT hesitate requiring NOT NULL columns when the app requires it.
migrator.registerMigration("appConfiguration") { db in
try db.create(table: "appConfiguration") { t in
t.primaryKey("id", .integer, onConflict: .replace).check { $0 == 1 }

t.column("flag", .boolean).notNull() // required
}
}

## The Single-Row Record

Now that the database schema has been defined, we can define the record type that will help the application access the single row:

struct AppConfiguration: Codable {
// Support for the single row guarantee
private var id = 1

// The stored properties
private var storedFlag: Bool?
// ... other properties
}

The `storedFlag` property is private, because we want to expose a nice `flag` property that has a default value when `storedFlag` is nil:

// Support for default values
extension AppConfiguration {
var flag: Bool {
get { storedFlag ?? true /* the default value */ }
set { storedFlag = newValue }
}

mutating func resetFlag() {
storedFlag = nil
}
}

This ceremony is not needed when the column can not be null:

// The simplified setup for non-nullable columns
struct AppConfiguration: Codable {
// Support for the single row guarantee
private var id = 1

// The stored properties
var flag: Bool
// ... other properties
}

In case the database table would be empty, we need a default configuration:

extension AppConfiguration {
/// The default configuration
static let `default` = AppConfiguration(flag: nil)
}

We make our record able to access the database:

extension AppConfiguration: FetchableRecord, PersistableRecord {

We have seen in the The Single-Row Table section that by default, updates throw an error if the database table is empty. To avoid this error, we instruct GRDB to insert the missing default configuration before attempting to update (see `willSave(_:)` for more information):

// Customize the default PersistableRecord behavior

// Insert the default configuration if it does not exist yet.
if try !exists(db) {
try AppConfiguration.default.insert(db)
}
}

The standard GRDB method `fetchOne(_:)` returns an optional which is nil when the database table is empty. As a convenience, let’s define a method that returns a non-optional (replacing the missing row with `default`):

/// Returns the persisted configuration, or the default one if the
/// database table is empty.

try fetchOne(db) ?? .default
}
}

And that’s it! Now we can use our singleton record:

// READ
let config = try dbQueue.read { db in
try AppConfiguration.find(db)
}
if config.flag {
// ...
}

// WRITE
try dbQueue.write { db in
// Update the config in the database
var config = try AppConfiguration.find(db)
try config.updateChanges(db) {
$0.flag = true
}

// Other possible ways to save the config:
var config = try AppConfiguration.find(db)
config.flag = true
try config.save(db) // all the same
try config.update(db) // all the same
try config.insert(db) // all the same
try config.upsert(db) // all the same
}

See `MutablePersistableRecord` for more information about persistence methods.

## Wrap-Up

We all love to copy and paste, don’t we? Just customize the template code below:

// Table creation
try db.create(table: "appConfiguration") { t in
// Single row guarantee: have inserts replace the existing row,
// and make sure the id column is always 1.
t.primaryKey("id", .integer, onConflict: .replace)
.check { $0 == 1 }

// The configuration columns
t.column("storedFlag", .boolean)
// ... other columns
}

//
// AppConfiguration.swift
//

import GRDB

extension AppConfiguration {
/// The default configuration
static let `default` = AppConfiguration(storedFlag: nil)
}

// Database Access
extension AppConfiguration: FetchableRecord, PersistableRecord {
// Customize the default PersistableRecord behavior

## See Also

### Records and the Query Interface

Record types and the query interface build SQL queries for you.

Recommended Practices for Designing Record Types

Leverage the best of record types and associations.

Record Timestamps and Transaction Date

Learn how applications can save creation and modification dates of records.

- Single-Row Tables
- Overview
- The Single-Row Table
- The Single-Row Record
- Wrap-Up
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseobservation

- GRDB
- Database Observation

API Collection

# Database Observation

Observe database changes and transactions.

## Overview

**SQLite notifies its host application of changes performed to the database, as well of transaction commits and rollbacks.**

GRDB puts this SQLite feature to some good use, and lets you observe the database in various ways:

- `ValueObservation`: Get notified when database values change.

- `DatabaseRegionObservation`: Get notified when a transaction impacts a database region.

- `afterNextTransaction(onCommit:onRollback:)`: Handle transactions commits or rollbacks, one by one.

- `TransactionObserver`: The low-level protocol that supports all database observation features.

## Topics

### Observing Database Values

`struct ValueObservation`

`ValueObservation` tracks changes in the results of database requests, and notifies fresh values whenever the database changes.

`class SharedValueObservation`

A shared value observation spares database resources by sharing a single underlying `ValueObservation` subscription.

`struct AsyncValueObservation`

An asynchronous sequence of values observed by a `ValueObservation`.

Reports the database region to `ValueObservation`.

### Observing Database Transactions

`struct DatabaseRegionObservation`

`DatabaseRegionObservation` tracks changes in a database region, and notifies impactful transactions.

Registers closures to be executed after the next or current transaction completes.

### Low-Level Transaction Observers

`protocol TransactionObserver`

A type that tracks database changes and transactions performed in a database.

`func add(transactionObserver: some TransactionObserver, extent: Database.TransactionObservationExtent)`

Adds a transaction observer on the database connection, so that it gets notified of database changes and transactions.

`func remove(transactionObserver: some TransactionObserver)`

Removes a transaction observer from the database connection.

Adds a transaction observer to the writer connection, so that it gets notified of database changes and transactions.

Removes a transaction observer from the writer connection.

`enum TransactionObservationExtent`

The extent of the observation performed by a `TransactionObserver`.

### Database Regions

`struct DatabaseRegion`

An observable region of the database.

`protocol DatabaseRegionConvertible`

A type that operates on a specific `DatabaseRegion`.

## See Also

### Application Tools

Search a corpus of textual documents.

Store and use JSON values in SQLite databases.

`enum DatabasePublishers`

A namespace for database Combine publishers.

- Database Observation
- Overview
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fulltextsearch

- GRDB
- Full-Text Search

API Collection

# Full-Text Search

Search a corpus of textual documents.

## Overview

Please refer to the Full-Text Search guide. It also describes how to enable support for the FTS5 engine.

## Topics

### Full-Text Engines

`struct FTS3`

The virtual table module for the FTS3 full-text engine.

`struct FTS4`

The virtual table module for the FTS4 full-text engine.

`struct FTS5`

The virtual table module for the FTS5 full-text engine.

## See Also

### Application Tools

Observe database changes and transactions.

Store and use JSON values in SQLite databases.

`enum DatabasePublishers`

A namespace for database Combine publishers.

- Full-Text Search
- Overview
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/json

- GRDB
- JSON Support

API Collection

# JSON Support

Store and use JSON values in SQLite databases.

## Overview

SQLite and GRDB can store and fetch JSON values in database columns. Starting , , , and , JSON values can be manipulated at the database level.

## Store and fetch JSON values

### JSON columns in the database schema

It is recommended to store JSON values in text columns. In the example below, we create a `jsonText` column with `create(table:options:body:)`:

try db.create(table: "player") { t in
t.primaryKey("id", .text)
t.column("name", .text).notNull()
t.column("address", .jsonText).notNull() // A JSON column
}

### Strict and flexible JSON schemas

Codable Records handle both strict and flexible JSON schemas.

**For strict schemas**, use `Codable` properties. They will be stored as JSON strings in the database:

struct Address: Codable {
var street: String
var city: String
var country: String
}

struct Player: Codable {
var id: String
var name: String

// Stored as a JSON string
// {"street": "...", "city": "...", "country": "..."}
var address: Address
}

extension Player: FetchableRecord, PersistableRecord { }

**For flexible schemas**, use `String` or `Data` properties.

In the specific case of `Data` properties, it is recommended to store them as text in the database, because SQLite JSON functions and operators are documented to throw errors if any of their arguments are binary blobs. This encoding is automatic with `DatabaseDataEncodingStrategy.text`:

// JSON String property
struct Player: Codable {
var id: String
var name: String
var address: String // JSON string
}

// JSON Data property, saved as text in the database
struct Team: Codable {
var id: String
var color: String
var info: Data // JSON UTF8 data
}

extension Team: FetchableRecord, PersistableRecord {
// Support SQLite JSON functions and operators
// by storing JSON data as database text:

.text
}
}

## Manipulate JSON values at the database level

SQLite JSON functions and operators are available starting , , , and .

Functions such as `JSON`, `JSON_EXTRACT`, `JSON_PATCH` and others are available as static methods on `Database`: `json(_:)`, `jsonExtract(_:atPath:)`, `jsonPatch(_:with:)`, etc.

See the full list below.

## JSON table-valued functions

The JSON table-valued functions `json_each` and `json_tree` are not supported.

## Topics

### JSON Values

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`struct JSONColumn`

A JSON column in a database table.

### Access JSON subcomponents, and query JSON values, at the SQL level

The `->` and `->>` SQL operators are available on the `SQLJSONExpressible` protocol.

The number of elements in a JSON array, as returned by the `JSON_ARRAY_LENGTH` SQL function.

The `JSON_EXTRACT` SQL function.

The `JSON_TYPE` SQL function.

### Build new JSON values at the SQL level

Validates and minifies a JSON string, with the `JSON` SQL function.

Creates a JSON array with the `JSON_ARRAY` SQL function.

Creates a JSON object with the `JSON_OBJECT` SQL function. Pass key/value pairs with a Swift collection such as a `Dictionary`.

Returns a valid JSON string with the `JSON_QUOTE` SQL function.

The `JSON_GROUP_ARRAY` SQL function.

The `JSON_GROUP_OBJECT` SQL function.

### Modify JSON values at the SQL level

The `JSON_INSERT` SQL function.

The `JSON_PATCH` SQL function.

The `JSON_REPLACE` SQL function.

The `JSON_REMOVE` SQL function.

The `JSON_SET` SQL function.

### Validate JSON values at the SQL level

The `JSON_VALID` SQL function.

## See Also

### Application Tools

Observe database changes and transactions.

Search a corpus of textual documents.

`enum DatabasePublishers`

A namespace for database Combine publishers.

- JSON Support
- Overview
- Store and fetch JSON values
- JSON columns in the database schema
- Strict and flexible JSON schemas
- Manipulate JSON values at the database level
- JSON table-valued functions
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasepublishers

- GRDB
- DatabasePublishers

Enumeration

# DatabasePublishers

A namespace for database Combine publishers.

enum DatabasePublishers

DatabasePublishers.swift

## Topics

### Structures

`struct DatabaseRegion`

A publisher that tracks transactions that modify a database region.

`struct Migrate`

A publisher that migrates a database.

`struct Read`

A publisher that reads from the database.

`struct Value`

A publisher that publishes the values of a `ValueObservation`.

`struct Write`

A publisher that writes into the database.

## See Also

### Application Tools

Observe database changes and transactions.

Search a corpus of textual documents.

Store and use JSON values in SQLite databases.

- DatabasePublishers
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/corefoundation

- GRDB
- CoreFoundation

Extended Module

# CoreFoundation

## Topics

### Extended Structures

`extension CGFloat`

CGFloat adopts DatabaseValueConvertible

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/foundation

- GRDB
- Foundation

Extended Module

# Foundation

## Topics

### Extended Classes

`extension NSData`

NSData is convertible to and from DatabaseValue.

`extension NSDate`

NSDate is stored in the database using the format “yyyy-MM-dd HH:mm:ss.SSS”, in the UTC time zone.

`extension NSNull`

NSNull adopts DatabaseValueConvertible

`extension NSNumber`

NSNumber adopts DatabaseValueConvertible

`extension NSString`

NSString adopts DatabaseValueConvertible

`extension NSURL`

NSURL stores its absoluteString in the database.

`extension NSUUID`

NSUUID adopts DatabaseValueConvertible

### Extended Structures

`extension Data`

Data is convertible to and from DatabaseValue.

`extension Date`

Date is stored in the database using the format “yyyy-MM-dd HH:mm:ss.SSS”, in the UTC time zone.

`extension Decimal`

Decimal adopts DatabaseValueConvertible

`extension URL`

URL stores its absoluteString in the database.

`extension UUID`

UUID adopts DatabaseValueConvertible

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/swift

- GRDB
- Swift

Extended Module

# Swift

## Topics

### Extended Protocols

`extension Collection`

`extension RangeReplaceableCollection`

`extension Sequence`

### Extended Structures

`extension Bool`

Bool adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension CountableClosedRange`

`extension Dictionary`

`extension Double`

Double adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension Float`

Float adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension Int`

Int adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension Int16`

Int16 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension Int32`

Int32 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension Int64`

Int64 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension Int8`

Int8 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension CountableRange`

`extension Set`

`extension String`

String adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension UInt`

UInt adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension UInt16`

UInt16 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension UInt32`

UInt32 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension UInt64`

UInt64 adopts DatabaseValueConvertible and StatementColumnConvertible.

`extension UInt8`

UInt8 adopts DatabaseValueConvertible and StatementColumnConvertible.

### Extended Enumerations

`extension Optional`

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/images/GRDB/GRDBLogo.png)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseconnections)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlsupport)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/concurrency)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/transactions)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschema)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/migrations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/queryinterface)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recordrecommendedpractices)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recordtimestamps)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/singlerowtables)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseobservation)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fulltextsearch)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/json)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasepublishers)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/corefoundation)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/foundation)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/swift)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(table:options:body:)

#app-main)

- GRDB
- The Database Schema
- Modifying the Database Schema
- create(table:options:body:)

Instance Method

# create(table:options:body:)

Creates a database table.

func create(
table name: String,
options: TableOptions = [],

) throws

Database+SchemaDefinition.swift

## Parameters

`name`

The table name.

`options`

Table creation options.

`body`

A closure that defines table columns and constraints.

### Reference documentation

SQLite has many reference documents about table creation. They are a great learning material:

- CREATE TABLE

- Datatypes In SQLite

- SQLite Foreign Key Support

- The ON CONFLICT Clause

- Rowid Tables

- The WITHOUT ROWID Optimization

- STRICT Tables

### Usage

// CREATE TABLE place (
// id INTEGER PRIMARY KEY AUTOINCREMENT,
// title TEXT,
// isFavorite BOOLEAN NOT NULL DEFAULT 0,
// latitude DOUBLE NOT NULL,
// longitude DOUBLE NOT NULL
// )
try db.create(table: "place") { t in
t.autoIncrementedPrimaryKey("id")
t.column("title", .text)
t.column("isFavorite", .boolean).notNull().default(false)
t.column("longitude", .double).notNull()
t.column("latitude", .double).notNull()
}

### Configure table creation

Use the `options` parameter to configure table creation (see `TableOptions`):

// CREATE TABLE player ( ... )
try db.create(table: "player") { t in ... }

// CREATE TEMPORARY TABLE player IF NOT EXISTS (
try db.create(table: "player", options: [.temporary, .ifNotExists]) { t in ... }

### Add columns

Add columns with their name and eventual type ( `text`, `integer`, `double`, `real`, `numeric`, `boolean`, `blob`, `date`, `datetime` and `any`) \- see `Database.ColumnType`:

// CREATE TABLE example (
// a,
// name TEXT,
// creationDate DATETIME,
try db.create(table: "example") { t in
t.column("a")
t.column("name", .text)
t.column("creationDate", .datetime)

The `column()` method returns a `ColumnDefinition` that you can further configure:

### Not null constraints, default values

// email TEXT NOT NULL,
t.column("email", .text).notNull()

// name TEXT DEFAULT 'O''Reilly',
t.column("name", .text).defaults(to: "O'Reilly")

// flag BOOLEAN NOT NULL DEFAULT 0,
t.column("flag", .boolean).notNull().defaults(to: false)

// creationDate DATETIME DEFAULT CURRENT_TIMESTAMP,
t.column("creationDate", .datetime).defaults(sql: "CURRENT_TIMESTAMP")

### Primary, unique, and foreign keys

Use an individual column as **primary**, **unique**, or **foreign key**. When defining a foreign key, the referenced column is the primary key of the referenced table (unless you specify otherwise):

// id INTEGER PRIMARY KEY AUTOINCREMENT,
t.autoIncrementedPrimaryKey("id")

// uuid TEXT NOT NULL PRIMARY KEY,
t.primaryKey("uuid", .text)

// email TEXT UNIQUE,
t.column("email", .text)
.unique()

// countryCode TEXT REFERENCES country(code) ON DELETE CASCADE,
t.column("countryCode", .text)
.references("country", onDelete: .cascade)

Primary, unique and foreign keys can also be added on several columns:

// a INTEGER NOT NULL,
// b TEXT NOT NULL,
// PRIMARY KEY (a, b)
t.primaryKey {
t.column("a", .integer)
t.column("b", .text)
}

// a INTEGER NOT NULL,
// b TEXT NOT NULL,
// PRIMARY KEY (a, b)
t.column("a", .integer).notNull()
t.column("b", .text).notNull()
t.primaryKey(["a", "b"])

// a INTEGER,
// b TEXT,
// UNIQUE (a, b) ON CONFLICT REPLACE
t.column("a", .integer)
t.column("b", .text)
t.uniqueKey(["a", "b"], onConflict: .replace)

// a INTEGER,
// b TEXT,
// FOREIGN KEY (a, b) REFERENCES parents(c, d)
t.column("a", .integer)
t.column("b", .text)
t.foreignKey(["a", "b"], references: "parents")

### Indexed columns

t.column("score", .integer).indexed()

For extra index options, see `create(indexOn:columns:options:condition:)`.

### Generated columns

See Generated columns for more information:

t.column("totalScore", .integer).generatedAs(sql: "score + bonus")
t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"))

### Integrity checks

SQLite will only let conforming rows in:

// CHECK (a + b < 10),
t.check(Column("a") + Column("b") < 10)

// CHECK (a + b < 10)
t.check(sql: "a + b < 10")

### Raw SQL columns and constraints

Columns and constraints can be defined with raw sql:

t.column(sql: "name TEXT")
t.constraint(sql: "CHECK (a + b < 10)")

`SQL` literals allow you to safely embed raw values in your SQL, without any risk of syntax errors or SQL injection:

let defaultName = "O'Reilly"
t.column(literal: "name TEXT DEFAULT \(defaultName)")

let forbiddenName = "admin"

## See Also

### Database Tables

Modifies a database table.

`func create(virtualTable: String, options: VirtualTableOptions, using: String) throws`

Creates a virtual database table.

`func drop(table: String) throws`

Deletes a database table.

`func dropFTS4SynchronizationTriggers(forTable: String) throws`

Deletes the synchronization triggers for a synchronized FTS4 table.

`func dropFTS5SynchronizationTriggers(forTable: String) throws`

Deletes the synchronization triggers for a synchronized FTS5 table.

`func rename(table: String, to: String) throws`

Renames a database table.

`struct ColumnType`

An SQL column type.

`enum ConflictResolution`

An SQLite conflict resolution.

`enum ForeignKeyAction`

A foreign key action.

`class TableAlteration`

A `TableDefinition` lets you modify the components of a database table.

`class TableDefinition`

A `TableDefinition` lets you define the components of a database table.

`struct TableOptions`

`protocol VirtualTableModule`

The protocol for SQLite virtual table modules.

`struct VirtualTableOptions`

Virtual table creation options.

- create(table:options:body:)
- Parameters
- Reference documentation
- Usage
- Configure table creation
- Add columns
- Not null constraints, default values
- Primary, unique, and foreign keys
- Indexed columns
- Generated columns
- Integrity checks
- Raw SQL columns and constraints
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemamodifications

- GRDB
- The Database Schema
- Modifying the Database Schema

API Collection

# Modifying the Database Schema

How to modify the database schema

## Overview

For modifying the database schema, prefer Swift methods over raw SQL queries. They allow the compiler to check if a schema change is available on the target operating system. Only use a raw SQL query when no Swift method exist (when creating triggers, for example).

When a schema change is not directly supported by SQLite, or not available on the target operating system, database tables have to be recreated. See Migrations for the detailed procedure.

## Create Tables

The `create(table:options:body:)` method covers nearly all SQLite table creation features. For virtual tables, see Full-Text Search, or use raw SQL.

// CREATE TABLE place (
// id INTEGER PRIMARY KEY AUTOINCREMENT,
// title TEXT,
// favorite BOOLEAN NOT NULL DEFAULT 0,
// latitude DOUBLE NOT NULL,
// longitude DOUBLE NOT NULL
// )
try db.create(table: "place") { t in
t.autoIncrementedPrimaryKey("id")
t.column("title", .text)
t.column("favorite", .boolean).notNull().defaults(to: false)
t.column("longitude", .double).notNull()
t.column("latitude", .double).notNull()
}

**Configure table creation**

// CREATE TABLE player ( ... )
try db.create(table: "player") { t in ... }

// CREATE TEMPORARY TABLE player IF NOT EXISTS (
try db.create(table: "player", options: [.temporary, .ifNotExists]) { t in ... }

Reference: `TableOptions`

**Add regular columns** with their name and eventual type ( `text`, `integer`, `double`, `real`, `numeric`, `boolean`, `blob`, `date`, `datetime`, `any`, and `json`) \- see SQLite data types and JSON Support:

// CREATE TABLE player (
// score,
// name TEXT,
// creationDate DATETIME,
// address TEXT,
try db.create(table: "player") { t in
t.column("score")
t.column("name", .text)
t.column("creationDate", .datetime)
t.column("address", .json)

Reference: `column(_:_:)`

Define **not null** columns, and set **default values**:

// email TEXT NOT NULL,
t.column("email", .text).notNull()

// name TEXT NOT NULL DEFAULT 'Anonymous',
t.column("name", .text).notNull().defaults(to: "Anonymous")

Reference: `ColumnDefinition`

**Define primary, unique, or foreign keys**. When defining a foreign key, the referenced column is the primary key of the referenced table (unless you specify otherwise):

// id INTEGER PRIMARY KEY AUTOINCREMENT,
t.autoIncrementedPrimaryKey("id")

// uuid TEXT PRIMARY KEY NOT NULL,
t.primaryKey("uuid", .text)

// teamName TEXT NOT NULL,
// position INTEGER NOT NULL,
// PRIMARY KEY (teamName, position),
t.primaryKey {
t.column("teamName", .text)
t.column("position", .integer)
}

// email TEXT UNIQUE,
t.column("email", .text).unique()

// teamId TEXT REFERENCES team(id) ON DELETE CASCADE,
// countryCode TEXT REFERENCES country(code) NOT NULL,
t.belongsTo("team", onDelete: .cascade)
t.belongsTo("country").notNull()

Reference: `TableDefinition`, `unique(onConflict:)`

**Create an index** on a column

t.column("score", .integer).indexed()

For extra index options, see Create Indexes below.

**Perform integrity checks** on individual columns, and SQLite will only let conforming rows in. In the example below, the `$0` closure variable is a column which lets you build any SQL expression.

Columns can also be defined with a raw sql String, or an SQL literal in which you can safely embed raw values without any risk of syntax errors or SQL injection:

t.column(sql: "name TEXT")

let defaultName: String = ...
t.column(literal: "name TEXT DEFAULT \(defaultName)")

Reference: `TableDefinition`

Other **table constraints** can involve several columns:

// PRIMARY KEY (a, b),
t.primaryKey(["a", "b"])

// UNIQUE (a, b) ON CONFLICT REPLACE,
t.uniqueKey(["a", "b"], onConflict: .replace)

// FOREIGN KEY (a, b) REFERENCES parents(c, d),
t.foreignKey(["a", "b"], references: "parents")

// CHECK (a + b < 10),
t.check(Column("a") + Column("b") < 10)

// CHECK (a + b < 10)
t.check(sql: "a + b < 10")

// Raw SQL constraints
t.constraint(sql: "CHECK (a + b < 10)")
t.constraint(literal: "CHECK (a + b < \(10))")

**Generated columns**:

t.column("totalScore", .integer).generatedAs(sql: "score + bonus")
t.column("totalScore", .integer).generatedAs(Column("score") + Column("bonus"))
}

## Modify Tables

SQLite lets you modify existing tables:

// ALTER TABLE referer RENAME TO referrer
try db.rename(table: "referer", to: "referrer")

// ALTER TABLE player ADD COLUMN hasBonus BOOLEAN
// ALTER TABLE player RENAME COLUMN url TO homeURL
// ALTER TABLE player DROP COLUMN score
try db.alter(table: "player") { t in
t.add(column: "hasBonus", .boolean)
t.rename(column: "url", to: "homeURL")
t.drop(column: "score")
}

Reference: `TableAlteration`

## Drop Tables

Drop tables with the `drop(table:)` method:

try db.drop(table: "obsolete")

## Create Indexes

Create an index on a column:

try db.create(table: "player") { t in
t.column("email", .text).unique()
t.column("score", .integer).indexed()
}

Create indexes on an existing table:

// CREATE INDEX index_player_on_email ON player(email)
try db.create(indexOn: "player", columns: ["email"])

// CREATE UNIQUE INDEX index_player_on_email ON player(email)
try db.create(indexOn: "player", columns: ["email"], options: .unique)

Create indexes with a specific collation:

// CREATE INDEX index_player_on_email ON player(email COLLATE NOCASE)
try db.create(
index: "index_player_on_email",
on: "player",
expressions: [Column("email").collating(.nocase)])

Create indexes on expressions:

// CREATE INDEX index_player_on_total_score ON player(score+bonus)
try db.create(
index: "index_player_on_total_score",
on: "player",
expressions: [Column("score") + Column("bonus")])

// CREATE INDEX index_player_on_country ON player(address ->> 'country')
try db.create(
index: "index_player_on_country",
on: "player",
expressions: [\
JSONColumn("address")["country"],\
])

Unique constraints and unique indexes are somewhat different: don’t miss the tip in Unique keys should be supported by unique indexes below.

## Topics

### Database Tables

Modifies a database table.

Creates a database table.

`func create(virtualTable: String, options: VirtualTableOptions, using: String) throws`

Creates a virtual database table.

`func drop(table: String) throws`

Deletes a database table.

`func dropFTS4SynchronizationTriggers(forTable: String) throws`

Deletes the synchronization triggers for a synchronized FTS4 table.

`func dropFTS5SynchronizationTriggers(forTable: String) throws`

Deletes the synchronization triggers for a synchronized FTS5 table.

`func rename(table: String, to: String) throws`

Renames a database table.

`struct ColumnType`

An SQL column type.

`enum ConflictResolution`

An SQLite conflict resolution.

`enum ForeignKeyAction`

A foreign key action.

`class TableAlteration`

A `TableDefinition` lets you modify the components of a database table.

`class TableDefinition`

A `TableDefinition` lets you define the components of a database table.

`struct TableOptions`

Table creation options.

`protocol VirtualTableModule`

The protocol for SQLite virtual table modules.

`struct VirtualTableOptions`

Virtual table creation options.

### Database Views

[`func create(view: String, options: ViewOptions, columns: [String]?, as: any SQLSubqueryable) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(view:options:columns:as:))

Creates a database view.

[`func create(view: String, options: ViewOptions, columns: [String]?, asLiteral: SQL) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(view:options:columns:asliteral:))

`func drop(view: String) throws`

Deletes a database view.

`struct ViewOptions`

View creation options

### Database Indexes

[`func create(indexOn: String, columns: [String], options: IndexOptions, condition: (any SQLExpressible)?) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(indexon:columns:options:condition:))

Creates an index with a default name on the specified table and columns.

[`func create(index: String, on: String, columns: [String], options: IndexOptions, condition: (any SQLExpressible)?) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(index:on:columns:options:condition:))

Creates an index on the specified table and columns.

[`func create(index: String, on: String, expressions: [any SQLExpressible], options: IndexOptions, condition: (any SQLExpressible)?) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(index:on:expressions:options:condition:))

Creates an index on the specified table and expressions.

[`func drop(indexOn: String, columns: [String]) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/drop(indexon:columns:))

Deletes the database index on the specified table and columns if exactly one such index exists.

`func drop(index: String) throws`

Deletes a database index.

`struct IndexOptions`

Index creation options

### Sunsetted Methods

Those are legacy interfaces that are preserved for backwards compatibility. Their use is not recommended.

[`func create(index: String, on: String, columns: [String], unique: Bool, ifNotExists: Bool, condition: (any SQLExpressible)?) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(index:on:columns:unique:ifnotexists:condition:))

`func create(virtualTable: String, ifNotExists: Bool, using: String) throws`

## See Also

### Define the database schema

Database Schema Recommendations

Recommendations for an ideal integration of the database schema with GRDB

- Modifying the Database Schema
- Overview
- Create Tables
- Modify Tables
- Drop Tables
- Create Indexes
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemarecommendations

- GRDB
- The Database Schema
- Database Schema Recommendations

Article

# Database Schema Recommendations

Recommendations for an ideal integration of the database schema with GRDB

## Overview

Even though all schema are supported, some features of the library and of the Swift language are easier to use when the schema follows a few conventions described below.

When those conventions are not applied, or not applicable, you will have to perform extra configurations.

For recommendations specific to JSON columns, see JSON Support.

## Table names should be English, singular, and camelCased

Make them look like singular Swift identifiers: `player`, `team`, `postalAddress`:

// RECOMMENDED
try db.create(table: "player") { t in
// table columns and constraints
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "players") { t in
// table columns and constraints
}

☝️ **If table names follow a different naming convention**, record types (see Records and the Query Interface) will need explicit table names:

extension Player: TableRecord {
// Required because table name is not 'player'
static let databaseTableName = "players"
}

extension PostalAddress: TableRecord {
// Required because table name is not 'postalAddress'
static let databaseTableName = "postal_address"
}

extension Award: TableRecord {
// Required because table name is not 'award'
static let databaseTableName = "Auszeichnung"
}

Associations will need explicit keys as well:

extension Player: TableRecord {
// Explicit association key because the table name is not 'postalAddress'
static let postalAddress = belongsTo(PostalAddress.self, key: "postalAddress")

// Explicit association key because the table name is not 'award'
static let awards = hasMany(Award.self, key: "awards")
}

As in the above example, make sure to-one associations use singular keys, and to-many associations use plural keys.

## Column names should be camelCased

Again, make them look like Swift identifiers: `fullName`, `score`, `creationDate`:

// RECOMMENDED
try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("fullName", .text).notNull()
t.column("score", .integer).notNull()
t.column("creationDate", .datetime).notNull()
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("full_name", .text).notNull()
t.column("score", .integer).notNull()
t.column("creation_date", .datetime).notNull()
}

☝️ **If the column names follow a different naming convention**, `Codable` record types will need an explicit `CodingKeys` enum:

struct Player: Decodable, FetchableRecord {
var id: Int64
var fullName: String
var score: Int
var creationDate: Date

// Required CodingKeys customization because
// columns are not named like Swift properties
enum CodingKeys: String, CodingKey {
case id, fullName = "full_name", score, creationDate = "creation_date"
}
}

## Tables should have explicit primary keys

A primary key uniquely identifies a row in a table. It is defined on one or several columns:

// RECOMMENDED
try db.create(table: "player") { t in
// Auto-incremented primary key
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
}

try db.create(table: "team") { t in
// Single-column primary key
t.primaryKey("id", .text)
t.column("name", .text).notNull()
}

try db.create(table: "membership") { t in
// Composite primary key
t.primaryKey {
t.belongsTo("player")
t.belongsTo("team")
}
t.column("role", .text).notNull()
}

Primary keys support record fetching methods such as `fetchOne(_:id:)`, and persistence methods such as `update(_:onConflict:)` or `delete(_:)`.

See Single-Row Tables when you need to define a table that contains a single row.

☝️ **If the database table does not define any explicit primary key**, identifying specific rows in this table needs explicit support for the hidden `rowid` column in the matching record types:

// A table without any explicit primary key
try db.create(table: "player") { t in
t.column("name", .text).notNull()
t.column("score", .integer).notNull()
}

// The record type for the 'player' table'
struct Player: Codable {
// Uniquely identifies a player.
var rowid: Int64?
var name: String
var score: Int
}

extension Player: FetchableRecord, MutablePersistableRecord {
// Required because the primary key
// is the hidden rowid column.
static var databaseSelection: [any SQLSelectable] {
[.allColumns, .rowID]
}

// Update id upon successful insertion
mutating func didInsert(_ inserted: InsertionSuccess) {
rowid = inserted.rowID
}
}

try dbQueue.read { db in
// SELECT *, rowid FROM player WHERE rowid = 1
if let player = try Player.fetchOne(db, id: 1) {
// DELETE FROM player WHERE rowid = 1
let deleted = try player.delete(db)
print(deleted) // true
}
}

## Single-column primary keys should be named ‘id’

This helps record types play well with the standard `Identifiable` protocol.

// RECOMMENDED
try db.create(table: "player") { t in
t.primaryKey("id", .text)
t.column("name", .text).notNull()
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "player") { t in
t.primaryKey("uuid", .text)
t.column("name", .text).notNull()
}

☝️ **If the primary key follows a different naming convention**, `Identifiable` record types will need a custom `CodingKeys` enum, or an extra property:

// Custom coding keys
struct Player: Codable, Identifiable {
var id: String
var name: String

// Required CodingKeys customization because
// columns are not named like Swift properties
enum CodingKeys: String, CodingKey {
case id = "uuid", name
}
}

// Extra property
struct Player: Identifiable {
var uuid: String
var name: String

// Required because the primary key column is not 'id'
var id: String { uuid }
}

## Unique keys should be supported by unique indexes

Unique indexes makes sure SQLite prevents the insertion of conflicting rows:

// RECOMMENDED
try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.belongsTo("team").notNull()
t.column("position", .integer).notNull()
// Players must have distinct names
t.column("name", .text).unique()
}

// One single player at any given position in a team
try db.create(
indexOn: "player",
columns: ["teamId", "position"],
options: .unique)

☝️ **If a table misses unique indexes**, some record methods such as `fetchOne(_:key:)` and `deleteOne(_:key:)` will raise a fatal error:

try dbQueue.write { db in
// Fatal error: table player has no unique index on columns ...
let player = try Player.fetchOne(db, key: ["teamId": 42, "position": 1])
try Player.deleteOne(db, key: ["name": "Arthur"])

// Use instead:
let player = try Player
.filter { $0.teamId == 42 && $0.position == 1 }
.fetchOne(db)

try Player
.filter { $0.name == "Arthur" }
.deleteAll(db)
}

## Relations between tables should be supported by foreign keys

Foreign Keys have SQLite enforce valid relationships between tables:

try db.create(table: "team") { t in
t.autoIncrementedPrimaryKey("id")
t.column("color", .text).notNull()
}

// RECOMMENDED
try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
// A player must refer to an existing team
t.belongsTo("team").notNull()
}

// REQUIRES EXTRA CONFIGURATION
try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
// No foreign key
t.column("teamId", .integer).notNull()
}

See `belongsTo(_:inTable:onDelete:onUpdate:deferred:indexed:)` for more information about the creation of foreign keys.

GRDB Associations are automatically configured from foreign keys declared in the database schema:

extension Player: TableRecord {
static let team = belongsTo(Team.self)
}

extension Team: TableRecord {
static let players = hasMany(Player.self)
}

See Associations and the Database Schema for more precise recommendations.

☝️ **If a foreign key is not declared in the schema**, you will need to explicitly configure related associations:

extension Player: TableRecord {
// Required configuration because the database does
// not declare any foreign key from players to their team.
static let teamForeignKey = ForeignKey(["teamId"])
static let team = belongsTo(Team.self,
using: teamForeignKey)
}

extension Team: TableRecord {
// Required configuration because the database does
// not declare any foreign key from players to their team.
static let players = hasMany(Player.self,
using: Player.teamForeignKey)
}

## See Also

### Define the database schema

How to modify the database schema

- Database Schema Recommendations
- Overview
- Table names should be English, singular, and camelCased
- Column names should be camelCased
- Tables should have explicit primary keys
- Single-column primary keys should be named ‘id’
- Unique keys should be supported by unique indexes
- Relations between tables should be supported by foreign keys
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemaintrospection

- GRDB
- The Database Schema
- Database Schema Introspection

API Collection

# Database Schema Introspection

Get information about schema objects such as tables, columns, indexes, foreign keys, etc.

## Topics

### Querying the Schema Version

Returns the current schema version ( `PRAGMA schema_version`).

### Existence Checks

Returns whether a table exists

Returns whether a trigger exists, in the main or temp schema, or in an attached database.

Returns whether a view exists, in the main or temp schema, or in an attached database.

### Table Structure

Returns the columns in a table or a view.

Returns the foreign keys defined on table named `tableName`.

The indexes on table named `tableName`.

The primary key for table named `tableName`.

Returns whether a sequence of columns uniquely identifies a row.

### Reserved Tables

Returns whether a table is an internal GRDB table.

Returns whether a table is an internal SQLite table.

### Supporting Types

`struct ColumnInfo`

Information about a column of a database table.

`struct ForeignKeyInfo`

Information about a foreign key.

`struct IndexInfo`

Information about an index.

`struct PrimaryKeyInfo`

Information about a primary key.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemaintegritychecks

- GRDB
- The Database Schema
- Integrity Checks

API Collection

# Integrity Checks

Perform integrity checks of the database content

## Topics

### Integrity Checks

`func checkForeignKeys() throws`

Throws an error if there exists a foreign key violation in the database.

`func checkForeignKeys(in: String, in: String?) throws`

Throws an error if there exists a foreign key violation in the table.

Returns a cursor over foreign key violations in the database.

Returns a cursor over foreign key violations in the table.

`struct ForeignKeyViolation`

A foreign key violation.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/create(table:options:body:)),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemamodifications).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/migrations).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemamodifications)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemarecommendations)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemaintrospection)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseschemaintegritychecks)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/%EF%BF%BD%EF%BF%BD%EF%BF%BD8%EF%BF%BD%DD%85%EF%BF%BD%04%047%EF%BF%BD:%13re%EF%BF%BD%EF%BF%BD%EF%BF%BD:TuFra/j6JPCbv%EF%BF%BD%13%17N%EF%BF%BD;%EF%BF%BD!;ke%20f%EF%BF%BD%D0%8E%0F%D7%99%EF%BF%BD!%DE%A2%EF%BF%BDw/%7C%EF%BF%BD%EF%BF%BDj%EF%BF%BD%02%EF%BF%BD%EF%BF%BD%EF%BF%BD/B%EF%BF%BDr%12%EF%BF%BD=:D%EF%BF%BD%EF%BF%BD%06%EF%BF%BDT&a$%EF%BF%BD%EF%BF%BD%EF%BF%BD%11Bd%EF%BF%BD%EF%BF%BD%EF%BF%BDf%EF%BF%BD/%7C%EF%BF%BDE:%EF%BF%BD%EF%BF%BD%EF%BF%BD%EF%BF%BD%EF%BF%BD$%EF%BF%BD%1Fr%EF%BF%BD%EF%BF%BD%EF%BF%BD%0B%EF%BF%BD%C2%A5%EF%BF%BD%18%1Dk%EF%BF%BD3NT%12L/]%EF%BF%BD%1E%EF%BF%BD%EF%BF%BDY%EF%BF%BDi/%60%0C%EF%BF%BD%EF%BF%BD%07%1A/_H%7F2%EF%BF%BD%EF%BF%BD%C6%A8pk%EF%BF%BDE%EF%BF%BD%EF%BF%BD%EF%BF%BD%039W2%DB%93%EF%BF%BD%1D/[%EF%BF%BD%EF%BF%BD%EF%BF%BDt

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasequeue

- GRDB
- Database Connections
- DatabaseQueue

Class

# DatabaseQueue

A database connection that serializes accesses to an SQLite database.

final class DatabaseQueue

DatabaseQueue.swift

## Usage

Open a `DatabaseQueue` with the path to a database file:

import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.

**A `DatabaseQueue` can be used from any thread.** The `write(_:)` and `read(_:)` methods are synchronous, and block the current thread until your database statements are executed in a protected dispatch queue:

// Modify the database:
try dbQueue.write { db in
try Player(name: "Arthur").insert(db)
}

// Read values:
try dbQueue.read { db in
let players = try Player.fetchAll(db)
let playerCount = try Player.fetchCount(db)
}

Database access methods can return values:

let playerCount = try dbQueue.read { db in
try Place.fetchCount(db)
}

try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

The `write(_:)` method wraps your database statements in a transaction that commits if and only if no error occurs. On the first unhandled error, all changes are reverted, the whole transaction is rollbacked, and the error is rethrown.

When you don’t need to modify the database, prefer the `read(_:)` method: it prevents any modification to the database.

When precise transaction handling is required, see Transactions and Savepoints.

Asynchronous database accesses are described in Concurrency.

`DatabaseQueue` can be configured with `Configuration`.

## In-Memory Databases

`DatabaseQueue` can open a connection to an in-memory SQLite database.

Such connections are quite handy for tests and SwiftUI previews, since you do not have to perform any cleanup of the file system.

let dbQueue = try DatabaseQueue()

In order to create several connections to the same in-memory database, give this database a name:

// A shared in-memory database
let dbQueue1 = try DatabaseQueue(named: "myDatabase")

// Another connection to the same database
let dbQueue2 = try DatabaseQueue(named: "myDatabase")

See `init(named:configuration:)`.

## Concurrency

A `DatabaseQueue` creates one single SQLite connection. All database accesses are executed in a serial **writer dispatch queue**, which means that there is never more than one thread that uses the database. The SQLite connection is closed when the `DatabaseQueue` is deallocated.

`DatabaseQueue` inherits most of its database access methods from the `DatabaseReader` and `DatabaseWriter` protocols. It defines a few specific database access methods as well, listed below.

A `DatabaseQueue` needs your application to follow rules in order to deliver its safety guarantees. See Concurrency for more information.

## Topics

### Creating a DatabaseQueue

`init(named: String?, configuration: Configuration) throws`

Opens an in-memory SQLite database.

`init(path: String, configuration: Configuration) throws`

Opens or creates an SQLite database.

Returns a connection to an in-memory copy of the database at `path`.

Returns a connection to a private, temporary, on-disk copy of the database at `path`.

### Accessing the Database

See `DatabaseReader` and `DatabaseWriter` for more database access methods.

Executes database operations, and returns their result after they have finished executing.

Wraps database operations inside a database transaction.

### Managing the SQLite Connection

`func releaseMemory()`

Free as much memory as possible.

### Instance Properties

`var configuration: Configuration`

`var path: String`

## Relationships

### Conforms To

- `DatabaseReader`
- `DatabaseWriter`
- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Connections for read and write accesses

`class DatabasePool`

A database connection that allows concurrent accesses to an SQLite database.

- DatabaseQueue
- Usage
- In-Memory Databases
- Concurrency
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasepool

- GRDB
- Database Connections
- DatabasePool

Class

# DatabasePool

A database connection that allows concurrent accesses to an SQLite database.

final class DatabasePool

DatabasePool.swift

## Usage

Open a `DatabasePool` with the path to a database file:

import GRDB

let dbPool = try DatabasePool(path: "/path/to/database.sqlite")

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.

**A `DatabasePool` can be used from any thread.** The `write(_:)` and `read(_:)` methods are synchronous, and block the current thread until your database statements are executed in a protected dispatch queue:

// Modify the database:
try dbPool.write { db in
try Player(name: "Arthur").insert(db)
}

// Read values:
try dbPool.read { db in
let players = try Player.fetchAll(db)
let playerCount = try Player.fetchCount(db)
}

Database access methods can return values:

let playerCount = try dbPool.read { db in
try Place.fetchCount(db)
}

try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

The `write(_:)` method wraps your database statements in a transaction that commits if and only if no error occurs. On the first unhandled error, all changes are reverted, the whole transaction is rollbacked, and the error is rethrown.

When you don’t need to modify the database, prefer the `read(_:)` method, because several threads can perform reads in parallel.

When precise transaction handling is required, see Transactions and Savepoints.

Asynchronous database accesses are described in Concurrency.

`DatabasePool` can take snapshots of the database: see `DatabaseSnapshot` and `DatabaseSnapshotPool`.

`DatabasePool` can be configured with `Configuration`.

## Concurrency

A `DatabasePool` creates one writer SQLite connection, and a pool of read-only SQLite connections.

Unless `readonly`, the database is set to the WAL mode. The WAL mode makes it possible for reads and writes to proceed concurrently.

All write accesses are executed in a serial **writer dispatch queue**, which means that there is never more than one thread that writes in the database.

All read accesses are executed in **reader dispatch queues** (one per read-only SQLite connection). Reads are generally non-blocking, unless the maximum number of concurrent reads has been reached. In this case, a read has to wait for another read to complete. That maximum number can be configured with `maximumReaderCount`.

SQLite connections are closed when the `DatabasePool` is deallocated.

`DatabasePool` inherits most of its database access methods from the `DatabaseReader` and `DatabaseWriter` protocols. It defines a few specific database access methods as well, listed below.

A `DatabasePool` needs your application to follow rules in order to deliver its safety guarantees. See Concurrency for more information.

## Topics

### Creating a DatabasePool

`init(path: String, configuration: Configuration) throws`

Opens or creates an SQLite database.

### Accessing the Database

See `DatabaseReader` and `DatabaseWriter` for more database access methods.

Performs an asynchronous read access.

Wraps database operations inside a database transaction.

### Creating Database Snapshots

Creates a database snapshot that serializes accesses to an unchanging database content, as it exists at the moment the snapshot is created.

Creates a database snapshot that allows concurrent accesses to an unchanging database content, as it exists at the moment the snapshot is created.

### Managing SQLite Connections

`func invalidateReadOnlyConnections()`

Invalidates open read-only SQLite connections.

`func releaseMemory()`

Frees as much memory as possible, by disposing non-essential memory.

`func releaseMemoryEventually()`

Eventually frees as much memory as possible, by disposing non-essential memory.

### Instance Properties

`var configuration: Configuration`

`var path: String`

The path to the database.

## Relationships

### Conforms To

- `DatabaseReader`
- `DatabaseWriter`
- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Connections for read and write accesses

`class DatabaseQueue`

A database connection that serializes accesses to an SQLite database.

- DatabasePool
- Usage
- Concurrency
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/close()

#app-main)

- GRDB
- Concurrency
- DatabaseReader
- close()

Instance Method

# close()

Closes the database connection.

func close() throws

DatabaseReader.swift

**Required**

## Discussion

If this method does not throw, then the database is properly closed, and every future database access will throw a `DatabaseError` of code `SQLITE_MISUSE`.

Otherwise, there exists concurrent database accesses or living prepared statements that prevent the database from closing, and this method throws a `DatabaseError` of code `SQLITE_BUSY`. See for more information.

After an error has been thrown, the database may still be opened, and you can keep on accessing it. It may also remain in a “zombie” state, in which case it will throw `SQLITE_MISUSE` for all future database accesses.

## See Also

### Other Database Operations

Copies the database contents into another database.

`func interrupt()`

Causes any pending database operation to abort and return at its earliest opportunity.

- close()
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/configuration

- GRDB
- Database Connections
- Configuration

Structure

# Configuration

The configuration of a database connection.

struct Configuration

Configuration.swift

## Overview

You create a `Configuration` before opening a database connection:

var config = Configuration()
config.readonly = true
config.maximumReaderCount = 2 // (DatabasePool only) The default is 5

let dbQueue = try DatabaseQueue( // or DatabasePool
path: "/path/to/database.sqlite",
configuration: config)

See Database Connections.

## Frequent Use Cases

#### Tracing SQL Statements

You can setup a tracing function that prints out all executed SQL requests with `prepareDatabase(_:)` and `trace(options:_:)`:

var config = Configuration()
config.prepareDatabase { db in

}

let dbQueue = try DatabaseQueue(
path: "/path/to/database.sqlite",
configuration: config)

let playerCount = dbQueue.read { db in
try Player.fetchCount(db)
}

#### Public Statement Arguments

Debugging is easier when database errors and tracing functions expose the values sent to the database. Since those values may contain sensitive information, verbose logging is disabled by default. You turn it on with `publicStatementArguments`:

var config = Configuration()
#if DEBUG
// Protect sensitive information by enabling
// verbose debugging in DEBUG builds only.
config.publicStatementArguments = true
#endif

do {
try dbQueue.write { db in
user.name = ...
user.location = ...
user.address = ...
user.phoneNumber = ...
try user.save(db)
}
} catch {
// Prints sensitive information in debug builds only
print(error)
}

## Topics

### Creating a Configuration

`init()`

Creates a factory configuration.

### Configuring SQLite Connections

`var acceptsDoubleQuotedStringLiterals: Bool`

A boolean value indicating whether SQLite 3.29+ interprets double-quoted strings as string literals when they does not match any valid identifier.

`var busyMode: Database.BusyMode`

Defines the how `SQLITE_BUSY` errors are handled.

`var foreignKeysEnabled: Bool`

A boolean value indicating whether foreign key support is enabled.

`var journalMode: Configuration.JournalModeConfiguration`

Defines how the journal mode is configured when the database connection is opened.

`var readonly: Bool`

A boolean value indicating whether an SQLite connection is read-only.

`enum JournalModeConfiguration`

### Configuring GRDB Connections

`var allowsUnsafeTransactions: Bool`

A boolean value indicating whether it is valid to leave a transaction opened at the end of a database access method.

`var label: String?`

A label that describes a database connection.

`var maximumReaderCount: Int`

The maximum number of concurrent reader connections.

`var observesSuspensionNotifications: Bool`

A boolean value indicating whether the database connection listens to the `suspendNotification` and `resumeNotification` notifications.

`var persistentReadOnlyConnections: Bool`

A boolean value indicating whether read-only connections should be kept open.

Defines a function to run whenever an SQLite connection is opened.

`var publicStatementArguments: Bool`

A boolean value indicating whether statement arguments are visible in the description of database errors and trace events.

`var transactionClock: any TransactionClock`

The clock that feeds `transactionDate`.

`protocol TransactionClock`

A type that provides the moment of a transaction.

### Configuring the Quality of Service

`var qos: DispatchQoS`

The quality of service of database accesses.

`var readQoS: DispatchQoS`

The effective quality of service of read-only database accesses.

`var writeQoS: DispatchQoS`

The effective quality of service of write database accesses.

`var targetQueue: DispatchQueue?`

The target dispatch queue for database accesses.

`var writeTargetQueue: DispatchQueue?`

The target dispatch queue for write database accesses.

## Relationships

### Conforms To

- `Swift.Sendable`

- Configuration
- Overview
- Frequent Use Cases
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasesnapshot

- GRDB
- Database Connections
- DatabaseSnapshot

Class

# DatabaseSnapshot

A database connection that serializes accesses to an unchanging database content, as it existed at the moment the snapshot was created.

final class DatabaseSnapshot

DatabaseSnapshot.swift

## Overview

A `DatabaseSnapshot` never sees any database modification during all its lifetime. All database accesses performed from a snapshot always see the same identical database content.

A snapshot creates one single SQLite connection. All database accesses are executed in a serial **reader dispatch queue**. The SQLite connection is closed when the `DatabaseSnapshot` is deallocated.

A snapshot created on a WAL database doesn’t prevent database modifications performed by other connections (but it won’t see them). Refer to Isolation In SQLite for more information.

On non-WAL databases, a snapshot prevents all database modifications as long as it exists, because of the SHARED lock it holds.

## Usage

You create instances of `DatabaseSnapshot` from a `DatabasePool`, with `makeSnapshot()`:

let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
let snapshot = try dbPool.makeSnapshot()
let playerCount = try snapshot.read { db in
try Player.fetchCount(db)
}

When you want to control the database state seen by a snapshot, create the snapshot from within a write access, outside of any transaction.

For example, compare the two snapshots below. The first one is guaranteed to see an empty table of players, because is is created after all players have been deleted, and from the serialized writer dispatch queue which prevents any concurrent write. The second is created without this concurrency protection, which means that some other threads may already have created some players:

try db.inTransaction {
try Player.deleteAll()
return .commit
}

return try dbPool.makeSnapshot()
}

// <- Other threads may have created some players here
let snapshot2 = try dbPool.makeSnapshot()

// Guaranteed to be zero
let count1 = try snapshot1.read { db in
try Player.fetchCount(db)
}

// Could be anything
let count2 = try snapshot2.read { db in
try Player.fetchCount(db)
}

`DatabaseSnapshot` inherits its database access methods from the `DatabaseReader` protocols.

`DatabaseSnapshot` serializes database accesses and can’t perform concurrent reads. For concurrent reads, see `DatabaseSnapshotPool`.

## Topics

### Instance Properties

`var configuration: Configuration`

`var path: String`

The path to the database file.

## Relationships

### Conforms To

- `DatabaseReader`
- `DatabaseSnapshotReader`
- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Read-only connections on an unchanging database content

`class DatabaseSnapshotPool`

A database connection that allows concurrent accesses to an unchanging database content, as it existed at the moment the snapshot was created.

- DatabaseSnapshot
- Overview
- Usage
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasesnapshotpool

- GRDB
- Database Connections
- DatabaseSnapshotPool

Class

# DatabaseSnapshotPool

A database connection that allows concurrent accesses to an unchanging database content, as it existed at the moment the snapshot was created.

final class DatabaseSnapshotPool

DatabaseSnapshotPool.swift

## Overview

A `DatabaseSnapshotPool` never sees any database modification during all its lifetime. All database accesses performed from a snapshot always see the same identical database content.

It creates a pool of up to `maximumReaderCount` read-only SQLite connections. All read accesses are executed in **reader dispatch queues** (one per read-only SQLite connection). SQLite connections are closed when the `DatabasePool` is deallocated.

An SQLite database in the WAL mode is required for creating a `DatabaseSnapshotPool`.

## Usage

You create a `DatabaseSnapshotPool` from a WAL mode database, such as databases created from a `DatabasePool`:

let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
let snapshot = try dbPool.makeSnapshotPool()

When you want to control the database state seen by a snapshot, create the snapshot from a database connection, outside of a write transaction. You can for example take snapshots from a `ValueObservation`:

// An observation of the 'player' table
// that notifies fresh database snapshots:
let observation = ValueObservation.tracking { db in
// Don't fetch players now, and return a snapshot instead.
// Register an access to the player table so that the
// observation tracks changes to this table.
try db.registerAccess(to: Player.all())
return try DatabaseSnapshotPool(db)
}

// Start observing the 'player' table
let cancellable = try observation.start(in: dbPool) { error in
// Handle error
} onChange: { (snapshot: DatabaseSnapshotPool) in
// Handle a fresh snapshot
}

`DatabaseSnapshotPool` inherits its database access methods from the `DatabaseReader` protocols.

Related SQLite documentation:

-

## Topics

### Creating a DatabaseSnapshotPool

See also `makeSnapshotPool()`.

`init(Database, configuration: Configuration?) throws`

Creates a snapshot of the database.

`init(path: String, configuration: Configuration) throws`

### Instance Properties

`let configuration: Configuration`

`let path: String`

The path to the database file.

## Relationships

### Conforms To

- `DatabaseReader`
- `DatabaseSnapshotReader`
- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Read-only connections on an unchanging database content

`class DatabaseSnapshot`

A database connection that serializes accesses to an unchanging database content, as it existed at the moment the snapshot was created.

- DatabaseSnapshotPool
- Overview
- Usage
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database

- GRDB
- Database Connections
- Database

Class

# Database

An SQLite connection.

final class Database

Database.swift

## Overview

You don’t create `Database` instances directly. Instead, you connect to a database with one of the Database Connections, and you use a database access method. For example:

let dbQueue = try DatabaseQueue()

try dbQueue.write { (db: Database) in
try Player(name: "Arthur").insert(db)
}

`Database` methods that modify, query, or validate the database schema are listed in The Database Schema.

## Topics

### Database Information

`var changesCount: Int`

The number of rows modified, inserted or deleted by the most recent successful INSERT, UPDATE or DELETE statement.

`let configuration: Configuration`

The database configuration.

`var debugDescription: String`

`let description: String`

A description of this database connection.

`var lastErrorCode: ResultCode`

The last error code.

`var lastErrorMessage: String?`

The last error message.

`var lastInsertedRowID: Int64`

The rowID of the most recently inserted row.

`var maximumStatementArgumentCount: Int`

The maximum number of arguments accepted by an SQLite statement.

`var sqliteConnection: SQLiteConnection?`

The raw SQLite connection, suitable for the SQLite C API.

`var totalChangesCount: Int`

The total number of rows modified, inserted or deleted by all successful INSERT, UPDATE or DELETE statements since the database connection was opened.

`typealias SQLiteConnection`

A raw SQLite connection, suitable for the SQLite C API.

### Database Statements

Returns a cursor of prepared statements.

Returns a prepared statement that can be reused.

`func execute(literal: SQL) throws`

Executes one or several SQL statements.

`func execute(sql: String, arguments: StatementArguments) throws`

Returns a new prepared statement that can be reused.

`class SQLStatementCursor`

A cursor over all statements in an SQL string.

### Database Transactions

`func beginTransaction(Database.TransactionKind?) throws`

Begins a database transaction.

`func commit() throws`

Commits a database transaction.

Wraps database operations inside a savepoint.

Wraps database operations inside a database transaction.

`var isInsideTransaction: Bool`

A Boolean value indicating whether the database connection is currently inside a transaction.

Executes read-only database operations, and returns their result after they have finished executing.

`func rollback() throws`

Rollbacks a database transaction.

`var transactionDate: Date`

The date of the current transaction.

`enum TransactionCompletion`

A transaction commit, or rollback.

`enum TransactionKind`

A transaction kind.

### Printing Database Content

`func dumpContent(format: some DumpFormat, to: (any TextOutputStream)?) throws`

Prints the contents of the database.

`func dumpRequest(some FetchRequest, format: some DumpFormat, to: (any TextOutputStream)?) throws`

Prints the results of a request.

`func dumpSchema(to: (any TextOutputStream)?) throws`

Prints the schema of the database.

`func dumpSQL(SQL, format: some DumpFormat, to: (any TextOutputStream)?) throws`

Prints the results of all statements in the provided SQL.

[`func dumpTables([String], format: some DumpFormat, tableHeader: DumpTableHeaderOptions, stableOrder: Bool, to: (any TextOutputStream)?) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/dumptables(_:format:tableheader:stableorder:to:))

Prints the contents of the provided tables and views.

`protocol DumpFormat`

A type that prints database rows.

`enum DumpTableHeaderOptions`

Options for printing table names.

### Database Observation

`func add(transactionObserver: some TransactionObserver, extent: Database.TransactionObservationExtent)`

Adds a transaction observer on the database connection, so that it gets notified of database changes and transactions.

`func remove(transactionObserver: some TransactionObserver)`

Removes a transaction observer from the database connection.

Registers closures to be executed after the next or current transaction completes.

`func notifyChanges(in: some DatabaseRegionConvertible) throws`

Notifies that some changes were performed in the provided database region.

Reports the database region to `ValueObservation`.

### Collations

`func add(collation: DatabaseCollation)`

Adds or redefines a collation.

`func reindex(collation: Database.CollationName) throws`

Deletes and recreates from scratch all indices that use this collation.

`func reindex(collation: DatabaseCollation) throws`

`func remove(collation: DatabaseCollation)`

Removes a collation.

`struct CollationName`

The name of a string comparison function used by SQLite.

`class DatabaseCollation`

`DatabaseCollation` is a custom string comparison function used by SQLite.

### SQL Functions

`func add(function: DatabaseFunction)`

Adds or redefines a custom SQL function.

`func remove(function: DatabaseFunction)`

Removes a custom SQL function.

`class DatabaseFunction`

A custom SQL function or aggregate.

### Notifications

`static let resumeNotification: Notification.Name`

When this notification is posted, databases which were opened with the `observesSuspensionNotifications` configuration flag are resumed.

`static let suspendNotification: Notification.Name`

When this notification is posted, databases which were opened with the `observesSuspensionNotifications` configuration flag are suspended.

### Other Database Operations

`func add(tokenizer: (some FTS5CustomTokenizer).Type)`

Add a custom FTS5 tokenizer.

Copies the database contents into another database.

Runs a WAL checkpoint.

`func clearSchemaCache()`

Clears the database schema cache.

`static var logError: Database.LogErrorFunction?`

The error logging function.

`func releaseMemory()`

Frees as much memory as possible.

`static var sqliteLibVersionNumber: CInt`

An integer equal to `SQLITE_VERSION_NUMBER`.

Registers a tracing function.

### Supporting Types

`typealias BusyCallback`

See `Database.BusyMode` and

`enum BusyMode`

When there are several connections to a database, a connection may try to access the database while it is locked by another connection.

`enum CheckpointMode`

The available checkpoint modes.

`struct DatabaseBackupProgress`

Describe the progress of a database backup.

`typealias LogErrorFunction`

An error log function that takes an error code and message.

`struct StorageClass`

An SQLite storage class.

`enum TraceEvent`

A trace event.

`struct TracingOptions`

An option for the SQLite tracing feature.

## Relationships

### Conforms To

- `Swift.CustomDebugStringConvertible`
- `Swift.CustomStringConvertible`

## See Also

### Using database connections

`struct DatabaseError`

A `DatabaseError` describes an SQLite error.

- Database
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseerror

- GRDB
- Database Connections
- DatabaseError

Structure

# DatabaseError

A `DatabaseError` describes an SQLite error.

struct DatabaseError

DatabaseError.swift

## Overview

For example:

do {
try player.insert(db)
} catch let error as DatabaseError {
print(error) // prints debugging information

switch error {
case DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY:
// foreign key constraint error
case DatabaseError.SQLITE_CONSTRAINT:
// any other constraint error
default:
// any other database error
}
}

The above example can also be written in a shorter way:

do {
try player.insert(db)
} catch DatabaseError.SQLITE_CONSTRAINT_FOREIGNKEY {
// foreign key constraint error
} catch DatabaseError.SQLITE_CONSTRAINT {
// any other constraint error
} catch {
// any other database error
}

Related SQLite documentation:

## Topics

### Creating DatabaseError

`init(resultCode: ResultCode, message: String?, sql: String?, arguments: StatementArguments?, publicStatementArguments: Bool)`

Creates a `DatabaseError`.

`struct ResultCode`

An SQLite result code.

### Error Information

`let arguments: StatementArguments?`

The query arguments that yielded the error.

`let extendedResultCode: ResultCode`

The SQLite extended error code.

`var isInterruptionError: Bool`

A boolean value indicating if the error has code `SQLITE_ABORT` or `SQLITE_INTERRUPT`.

`let message: String?`

The SQLite error message.

`var resultCode: ResultCode`

The SQLite primary result code.

`let sql: String?`

The SQL query that yielded the error.

### Converting DatabaseError to String

`var description: String`

The error description.

`var expandedDescription: String`

The error description, where bound parameters, if present, are visible.

### Type Properties

`static let SQLITE_ABORT: ResultCode`

`static let SQLITE_ABORT_ROLLBACK: ResultCode`

`static let SQLITE_AUTH: ResultCode`

`static let SQLITE_AUTH_USER: ResultCode`

`static let SQLITE_BUSY: ResultCode`

`static let SQLITE_BUSY_RECOVERY: ResultCode`

`static let SQLITE_BUSY_SNAPSHOT: ResultCode`

`static let SQLITE_BUSY_TIMEOUT: ResultCode`

`static let SQLITE_CANTOPEN: ResultCode`

`static let SQLITE_CANTOPEN_CONVPATH: ResultCode`

`static let SQLITE_CANTOPEN_DIRTYWAL: ResultCode`

`static let SQLITE_CANTOPEN_FULLPATH: ResultCode`

`static let SQLITE_CANTOPEN_ISDIR: ResultCode`

`static let SQLITE_CANTOPEN_NOTEMPDIR: ResultCode`

`static let SQLITE_CANTOPEN_SYMLINK: ResultCode`

`static let SQLITE_CONSTRAINT: ResultCode`

`static let SQLITE_CONSTRAINT_CHECK: ResultCode`

`static let SQLITE_CONSTRAINT_COMMITHOOK: ResultCode`

`static let SQLITE_CONSTRAINT_DATATYPE: ResultCode`

`static let SQLITE_CONSTRAINT_FOREIGNKEY: ResultCode`

`static let SQLITE_CONSTRAINT_FUNCTION: ResultCode`

`static let SQLITE_CONSTRAINT_NOTNULL: ResultCode`

`static let SQLITE_CONSTRAINT_PINNED: ResultCode`

`static let SQLITE_CONSTRAINT_PRIMARYKEY: ResultCode`

`static let SQLITE_CONSTRAINT_ROWID: ResultCode`

`static let SQLITE_CONSTRAINT_TRIGGER: ResultCode`

`static let SQLITE_CONSTRAINT_UNIQUE: ResultCode`

`static let SQLITE_CONSTRAINT_VTAB: ResultCode`

`static let SQLITE_CORRUPT: ResultCode`

`static let SQLITE_CORRUPT_INDEX: ResultCode`

`static let SQLITE_CORRUPT_SEQUENCE: ResultCode`

`static let SQLITE_CORRUPT_VTAB: ResultCode`

`static let SQLITE_DONE: ResultCode`

`static let SQLITE_EMPTY: ResultCode`

`static let SQLITE_ERROR: ResultCode`

`static let SQLITE_ERROR_MISSING_COLLSEQ: ResultCode`

`static let SQLITE_ERROR_RETRY: ResultCode`

`static let SQLITE_ERROR_SNAPSHOT: ResultCode`

`static let SQLITE_FORMAT: ResultCode`

`static let SQLITE_FULL: ResultCode`

`static let SQLITE_INTERNAL: ResultCode`

`static let SQLITE_INTERRUPT: ResultCode`

`static let SQLITE_IOERR: ResultCode`

`static let SQLITE_IOERR_ACCESS: ResultCode`

`static let SQLITE_IOERR_AUTH: ResultCode`

`static let SQLITE_IOERR_BEGIN_ATOMIC: ResultCode`

`static let SQLITE_IOERR_BLOCKED: ResultCode`

`static let SQLITE_IOERR_CHECKRESERVEDLOCK: ResultCode`

`static let SQLITE_IOERR_CLOSE: ResultCode`

`static let SQLITE_IOERR_COMMIT_ATOMIC: ResultCode`

`static let SQLITE_IOERR_CONVPATH: ResultCode`

`static let SQLITE_IOERR_CORRUPTFS: ResultCode`

`static let SQLITE_IOERR_DATA: ResultCode`

`static let SQLITE_IOERR_DELETE: ResultCode`

`static let SQLITE_IOERR_DELETE_NOENT: ResultCode`

`static let SQLITE_IOERR_DIR_CLOSE: ResultCode`

`static let SQLITE_IOERR_DIR_FSYNC: ResultCode`

`static let SQLITE_IOERR_FSTAT: ResultCode`

`static let SQLITE_IOERR_FSYNC: ResultCode`

`static let SQLITE_IOERR_GETTEMPPATH: ResultCode`

`static let SQLITE_IOERR_LOCK: ResultCode`

`static let SQLITE_IOERR_MMAP: ResultCode`

`static let SQLITE_IOERR_NOMEM: ResultCode`

`static let SQLITE_IOERR_RDLOCK: ResultCode`

`static let SQLITE_IOERR_READ: ResultCode`

`static let SQLITE_IOERR_ROLLBACK_ATOMIC: ResultCode`

`static let SQLITE_IOERR_SEEK: ResultCode`

`static let SQLITE_IOERR_SHMLOCK: ResultCode`

`static let SQLITE_IOERR_SHMMAP: ResultCode`

`static let SQLITE_IOERR_SHMOPEN: ResultCode`

`static let SQLITE_IOERR_SHMSIZE: ResultCode`

`static let SQLITE_IOERR_SHORT_READ: ResultCode`

`static let SQLITE_IOERR_TRUNCATE: ResultCode`

`static let SQLITE_IOERR_UNLOCK: ResultCode`

`static let SQLITE_IOERR_VNODE: ResultCode`

`static let SQLITE_IOERR_WRITE: ResultCode`

`static let SQLITE_LOCKED: ResultCode`

`static let SQLITE_LOCKED_SHAREDCACHE: ResultCode`

`static let SQLITE_LOCKED_VTAB: ResultCode`

`static let SQLITE_MISMATCH: ResultCode`

`static let SQLITE_MISUSE: ResultCode`

`static let SQLITE_NOLFS: ResultCode`

`static let SQLITE_NOMEM: ResultCode`

`static let SQLITE_NOTADB: ResultCode`

`static let SQLITE_NOTFOUND: ResultCode`

`static let SQLITE_NOTICE: ResultCode`

`static let SQLITE_NOTICE_RECOVER_ROLLBACK: ResultCode`

`static let SQLITE_NOTICE_RECOVER_WAL: ResultCode`

`static let SQLITE_OK: ResultCode`

`static let SQLITE_OK_LOAD_PERMANENTLY: ResultCode`

`static let SQLITE_OK_SYMLINK: ResultCode`

`static let SQLITE_PERM: ResultCode`

`static let SQLITE_PROTOCOL: ResultCode`

`static let SQLITE_RANGE: ResultCode`

`static let SQLITE_READONLY: ResultCode`

`static let SQLITE_READONLY_CANTINIT: ResultCode`

`static let SQLITE_READONLY_CANTLOCK: ResultCode`

`static let SQLITE_READONLY_DBMOVED: ResultCode`

`static let SQLITE_READONLY_DIRECTORY: ResultCode`

`static let SQLITE_READONLY_RECOVERY: ResultCode`

`static let SQLITE_READONLY_ROLLBACK: ResultCode`

`static let SQLITE_ROW: ResultCode`

`static let SQLITE_SCHEMA: ResultCode`

`static let SQLITE_TOOBIG: ResultCode`

`static let SQLITE_WARNING: ResultCode`

`static let SQLITE_WARNING_AUTOINDEX: ResultCode`

## Relationships

### Conforms To

- `Foundation.CustomNSError`
- `Swift.Copyable`
- `Swift.CustomStringConvertible`
- `Swift.Error`
- `Swift.Sendable`

## See Also

### Using database connections

`class Database`

An SQLite connection.

- DatabaseError
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasequeue)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasepool):

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasepool)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/close()).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlsupport).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/queryinterface).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/configuration)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasesnapshot)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasesnapshotpool)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseerror)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord

- GRDB
- Records and the Query Interface
- MutablePersistableRecord

Protocol

# MutablePersistableRecord

A type that can be persisted in the database, and mutates on insertion.

protocol MutablePersistableRecord : EncodableRecord, TableRecord

MutablePersistableRecord.swift

## Overview

A `MutablePersistableRecord` instance mutates on insertion. This protocol is suited for record types that are a `struct`, and target a database table where ids are generated on insertion. Such records implement the `didInsert(_:)` callback in order to grab this id. For example:

// CREATE TABLE player (
// id INTEGER PRIMARY KEY AUTOINCREMENT,
// name TEXT NOT NULL,
// score INTEGER NOT NULL
// )
struct Player: Encodable {
var id: Int64?
var name: String
var score: Int
}

extension Player: MutablePersistableRecord {
mutating func didInsert(_ inserted: InsertionSuccess) {
id = inserted.rowID
}
}

try dbQueue.write { db in
var player = Player(id: nil, name:: "Arthur", score: 1000)
try player.insert(db)
print(player.id) // Some id that is not nil
}

Other record types (classes, and generally records that do not mutate on insertion) should prefer the `PersistableRecord` protocol instead.

## Conforming to the MutablePersistableRecord Protocol

To conform to `MutablePersistableRecord`, provide an implementation for the `encode(to:)` method. This implementation is ready-made for `Encodable` types.

You configure the database table where records are persisted with the `TableRecord` inherited protocol.

## Topics

### Testing if a Record Exists in the Database

Returns whether the primary key of the record matches a row in the database.

### Inserting a Record

`func insert(Database, onConflict: Database.ConflictResolution?) throws`

Executes an `INSERT` statement.

Executes an `INSERT` statement, and returns the inserted record.

`func upsert(Database) throws`

Executes an `INSERT ON CONFLICT DO UPDATE` statement.

### Inserting a Record and Fetching the Inserted Row

Executes an `INSERT RETURNING` statement, and returns a new record built from the inserted row.

Executes an `INSERT RETURNING` statement, and returns the selected columns from the inserted row.

Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and returns the upserted record.

### Updating a Record

See inherited `TableRecord` methods for batch updates.

`func update(Database, onConflict: Database.ConflictResolution?) throws`

Executes an `UPDATE` statement on all columns.

Executes an `UPDATE` statement on the provided columns.

`func update(Database, onConflict: Database.ConflictResolution?, columns: some Collection) throws`

If the record has any difference from the other record, executes an `UPDATE` statement so that those differences and only those differences are updated in the database.

Modifies the record according to the provided `modify` closure, and executes an `UPDATE` statement that updates the modified columns, if and only if the record was modified.

### Updating a Record and Fetching the Updated Row

Executes an `UPDATE RETURNING` statement on all columns, and returns a new record built from the updated row.

Executes an `UPDATE RETURNING` statement on the provided columns, and returns the selected columns from the updated row.

Executes an `UPDATE RETURNING` statement on all columns, and returns the selected columns from the updated row.

Modifies the record according to the provided `modify` closure, and executes an `UPDATE RETURNING` statement that updates the modified columns, if and only if the record was modified. The method returns a new record built from the updated row.

### Saving a Record

`func save(Database, onConflict: Database.ConflictResolution?) throws`

Executes an `INSERT` or `UPDATE` statement.

Executes an `INSERT` or `UPDATE` statement, and returns the saved record.

### Saving a Record and Fetching the Saved Row

Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and returns a new record built from the saved row.

Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and returns the selected columns from the saved row.

### Deleting a Record

See inherited `TableRecord` methods for batch deletes.

Executes a DELETE statement.

### Persistence Callbacks

`func willDelete(Database) throws`

Persistence callback called before the record is deleted.

**Required** Default implementation provided.

`func willInsert(Database) throws`

Persistence callback called before the record is inserted.

**Required** Default implementations provided.

`func willSave(Database) throws`

Persistence callback called before the record is updated or inserted.

Persistence callback called before the record is updated.

`func didDelete(deleted: Bool)`

Persistence callback called upon successful deletion.

`func didInsert(InsertionSuccess)`

Persistence callback called upon successful insertion.

`func didSave(PersistenceSuccess)`

Persistence callback called upon successful update or insertion.

`func didUpdate(PersistenceSuccess)`

Persistence callback called upon successful update.

Persistence callback called around the destruction of the record.

Persistence callback called around the record insertion.

Persistence callback called around the record update or insertion.

Persistence callback called around the record update.

`struct InsertionSuccess`

The result of a successful record insertion.

`struct PersistenceSuccess`

The result of a successful record persistence (insert or update).

### Configuring Persistence

`static var persistenceConflictPolicy: PersistenceConflictPolicy`

The policy that handles SQLite conflicts when records are inserted or updated.

`struct PersistenceConflictPolicy`

The `MutablePersistableRecord` protocol uses this type in order to handle SQLite conflicts when records are inserted or updated.

## Relationships

### Inherits From

- `EncodableRecord`
- `TableRecord`

### Inherited By

- `PersistableRecord`

### Conforming Types

- `Record`

## See Also

### Records Protocols

`protocol EncodableRecord`

A type that can encode itself in a database row.

`protocol FetchableRecord`

A type that can decode itself from a database row.

`protocol PersistableRecord`

A type that can be persisted in the database.

`protocol TableRecord`

A type that builds database queries with the Swift language instead of SQL.

- MutablePersistableRecord
- Overview
- Conforming to the MutablePersistableRecord Protocol
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/willinsert(_:)-1xfwo

-1xfwo#app-main)

- GRDB
- Records and the Query Interface
- MutablePersistableRecord
- willInsert(\_:)

Instance Method

# willInsert(\_:)

Persistence callback called before the record is inserted.

mutating func willInsert(_ db: Database) throws

MutablePersistableRecord.swift

**Required** Default implementations provided.

## Parameters

`db`

A database connection.

## Discussion

Default implementation does nothing.

## Default Implementations

### MutablePersistableRecord Implementations

`func willInsert(Database) throws`

## See Also

### Persistence Callbacks

`func willDelete(Database) throws`

Persistence callback called before the record is deleted.

**Required** Default implementation provided.

`func willSave(Database) throws`

Persistence callback called before the record is updated or inserted.

Persistence callback called before the record is updated.

`func didDelete(deleted: Bool)`

Persistence callback called upon successful deletion.

`func didInsert(InsertionSuccess)`

Persistence callback called upon successful insertion.

`func didSave(PersistenceSuccess)`

Persistence callback called upon successful update or insertion.

`func didUpdate(PersistenceSuccess)`

Persistence callback called upon successful update.

Persistence callback called around the destruction of the record.

Persistence callback called around the record insertion.

Persistence callback called around the record update or insertion.

Persistence callback called around the record update.

`struct InsertionSuccess`

The result of a successful record insertion.

`struct PersistenceSuccess`

The result of a successful record persistence (insert or update).

- willInsert(\_:)
- Parameters
- Discussion
- Default Implementations
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/transactiondate

- GRDB
- Database Connections
- Database
- transactionDate

Instance Property

# transactionDate

The date of the current transaction.

var transactionDate: Date { get throws }

Database.swift

## Discussion

The returned date is constant at any point during a transaction. It is set when the database leaves the autocommit mode with a `BEGIN` statement.

When the database is not currently in a transaction, a new date is returned on each call.

See Record Timestamps and Transaction Date for an example of usage.

The transaction date, by default, is the start date of the current transaction. You can override this default behavior by configuring `transactionClock`.

## See Also

### Database Transactions

`func beginTransaction(Database.TransactionKind?) throws`

Begins a database transaction.

`func commit() throws`

Commits a database transaction.

Wraps database operations inside a savepoint.

Wraps database operations inside a database transaction.

`var isInsideTransaction: Bool`

A Boolean value indicating whether the database connection is currently inside a transaction.

Executes read-only database operations, and returns their result after they have finished executing.

`func rollback() throws`

Rollbacks a database transaction.

`enum TransactionCompletion`

A transaction commit, or rollback.

`enum TransactionKind`

A transaction kind.

- transactionDate
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/configuration/transactionclock

- GRDB
- Database Connections
- Configuration
- transactionClock

Instance Property

# transactionClock

The clock that feeds `transactionDate`.

var transactionClock: any TransactionClock

Configuration.swift

## Discussion

The default clock is `DefaultTransactionClock` (which returns the start date of the current transaction).

For example:

var config = Configuration()
config.transactionClock = .custom { db in /* return some Date */ }

## See Also

### Configuring GRDB Connections

`var allowsUnsafeTransactions: Bool`

A boolean value indicating whether it is valid to leave a transaction opened at the end of a database access method.

`var label: String?`

A label that describes a database connection.

`var maximumReaderCount: Int`

The maximum number of concurrent reader connections.

`var observesSuspensionNotifications: Bool`

A boolean value indicating whether the database connection listens to the `suspendNotification` and `resumeNotification` notifications.

`var persistentReadOnlyConnections: Bool`

A boolean value indicating whether read-only connections should be kept open.

Defines a function to run whenever an SQLite connection is opened.

`var publicStatementArguments: Bool`

A boolean value indicating whether statement arguments are visible in the description of database errors and trace events.

`protocol TransactionClock`

A type that provides the moment of a transaction.

- transactionClock
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/insertandfetch(_:onconflict:as:)

#app-main)

- GRDB
- Records and the Query Interface
- MutablePersistableRecord
- insertAndFetch(\_:onConflict:as:)

Instance Method

# insertAndFetch(\_:onConflict:as:)

Executes an `INSERT RETURNING` statement, and returns a new record built from the inserted row.

_ db: Database,
onConflict conflictResolution: Database.ConflictResolution? = nil,
as returnedType: T.Type

MutablePersistableRecord+Insert.swift

## Parameters

`db`

A database connection.

`conflictResolution`

A policy for conflict resolution. If nil, `persistenceConflictPolicy` is used.

`returnedType`

The type of the returned record.

## Return Value

A record of type `returnedType`.

## Discussion

This method helps dealing with default column values and generated columns.

For example:

// A table with an auto-incremented primary key and a default value
try dbQueue.write { db in
try db.execute(sql: """
CREATE TABLE player(
id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT,
score INTEGER DEFAULT 1000)
""")
}

// A player with partial database information
struct PartialPlayer: MutablePersistableRecord {
static let databaseTableName = "player"
var name: String
}

// A full player, with all database information
struct Player: TableRecord, FetchableRecord {
var id: Int64
var name: String
var score: Int
}

// Insert a partial player, get a full one
try dbQueue.write { db in
var partialPlayer = PartialPlayer(name: "Alice")

// INSERT INTO player (name) VALUES ('Alice') RETURNING *
let player = try partialPlayer.insertAndFetch(db, as: FullPlayer.self)
print(player.id) // The inserted id
print(player.name) // The inserted name
print(player.score) // The default score
}

## See Also

### Inserting a Record and Fetching the Inserted Row

Executes an `INSERT RETURNING` statement, and returns the selected columns from the inserted row.

Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and returns the upserted record.

- insertAndFetch(\_:onConflict:as:)
- Parameters
- Return Value
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/update(_:onconflict:)

#app-main)

- GRDB
- Records and the Query Interface
- MutablePersistableRecord
- update(\_:onConflict:)

Instance Method

# update(\_:onConflict:)

Executes an `UPDATE` statement on all columns.

func update(
_ db: Database,
onConflict conflictResolution: Database.ConflictResolution? = nil
) throws

MutablePersistableRecord+Update.swift

## Parameters

`db`

A database connection.

`conflictResolution`

A policy for conflict resolution. If nil, `persistenceConflictPolicy` is used.

## Discussion

For example:

try dbQueue.write { db in
var player = Player.find(db, id: 1)
player.score += 10
try player.update(db)
}

## See Also

### Updating a Record

Executes an `UPDATE` statement on the provided columns.

`func update(Database, onConflict: Database.ConflictResolution?, columns: some Collection) throws`

If the record has any difference from the other record, executes an `UPDATE` statement so that those differences and only those differences are updated in the database.

Modifies the record according to the provided `modify` closure, and executes an `UPDATE` statement that updates the modified columns, if and only if the record was modified.

- update(\_:onConflict:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/updatechanges(_:onconflict:modify:)

#app-main)

- GRDB
- Records and the Query Interface
- MutablePersistableRecord
- updateChanges(\_:onConflict:modify:)

Instance Method

# updateChanges(\_:onConflict:modify:)

Modifies the record according to the provided `modify` closure, and executes an `UPDATE` statement that updates the modified columns, if and only if the record was modified.

@discardableResult
mutating func updateChanges(
_ db: Database,
onConflict conflictResolution: Database.ConflictResolution? = nil,

MutablePersistableRecord+Update.swift

## Parameters

`db`

A database connection.

`conflictResolution`

A policy for conflict resolution. If nil, `persistenceConflictPolicy` is used.

`modify`

A closure that modifies the record.

## Return Value

Whether the record was changed and updated.

## Discussion

For example:

try dbQueue.write { db in
var player = Player.find(db, id: 1)
let modified = try player.updateChanges(db) {
$0.score = 1000
$0.hasAward = true
}
if modified {
print("player was modified")
} else {
print("player was not modified")
}
}

## See Also

### Updating a Record

`func update(Database, onConflict: Database.ConflictResolution?) throws`

Executes an `UPDATE` statement on all columns.

Executes an `UPDATE` statement on the provided columns.

`func update(Database, onConflict: Database.ConflictResolution?, columns: some Collection) throws`

If the record has any difference from the other record, executes an `UPDATE` statement so that those differences and only those differences are updated in the database.

- updateChanges(\_:onConflict:modify:)
- Parameters
- Return Value
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/save(_:onconflict:)

#app-main)

- GRDB
- Records and the Query Interface
- MutablePersistableRecord
- save(\_:onConflict:)

Instance Method

# save(\_:onConflict:)

Executes an `INSERT` or `UPDATE` statement.

mutating func save(
_ db: Database,
onConflict conflictResolution: Database.ConflictResolution? = nil
) throws

MutablePersistableRecord+Save.swift

## Parameters

`db`

A database connection.

`conflictResolution`

A policy for conflict resolution. If nil, `persistenceConflictPolicy` is used.

## Discussion

If the receiver has a non-nil primary key and a matching row in the database, this method performs an update.

Otherwise, performs an insert.

## See Also

### Saving a Record

Executes an `INSERT` or `UPDATE` statement, and returns the saved record.

- save(\_:onConflict:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/willinsert(_:)-1xfwo)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/transactiondate)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/configuration/transactionclock),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/transactiondate),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/insertandfetch(_:onconflict:as:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/update(_:onconflict:)),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/updatechanges(_:onconflict:modify:)),



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/mutablepersistablerecord/save(_:onconflict:)).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/encodablerecord

- GRDB
- Records and the Query Interface
- EncodableRecord

Protocol

# EncodableRecord

A type that can encode itself in a database row.

protocol EncodableRecord

EncodableRecord.swift

## Overview

To conform to `EncodableRecord`, provide an implementation for the `encode(to:)` method. This implementation is ready-made for `Encodable` types.

Most of the time, your record types will get `EncodableRecord` conformance through the `MutablePersistableRecord` or `PersistableRecord` protocols, which provide persistence methods.

## Topics

### Encoding a Database Row

`func encode(to: inout PersistenceContainer) throws`

Encodes the record into the provided persistence container.

**Required** Default implementation provided.

`struct PersistenceContainer`

A container for database values to store in a database row.

### Configuring Persistence for the Standard Encodable Protocol

`static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy`

The strategy for converting coding keys to column names.

The strategy for encoding `Data` columns.

The strategy for encoding `Date` columns.

Returns the `JSONEncoder` that encodes the value for a given column.

The strategy for encoding `UUID` columns.

[`static var databaseEncodingUserInfo: [CodingUserInfoKey : Any]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/encodablerecord/databaseencodinguserinfo-8upii)

Contextual information made available to the `Encodable.encode(to:)` method.

`enum DatabaseColumnEncodingStrategy`

`DatabaseColumnEncodingStrategy` specifies how `EncodableRecord` types that also adopt the standard `Encodable` protocol encode their coding keys into database columns in the default `encode(to:)` implementation.

`enum DatabaseDataEncodingStrategy`

`DatabaseDataEncodingStrategy` specifies how `EncodableRecord` types that also adopt the standard `Encodable` protocol encode their `Data` properties in the default `encode(to:)` implementation.

`enum DatabaseDateEncodingStrategy`

`DatabaseDateEncodingStrategy` specifies how `EncodableRecord` types that also adopt the standard `Encodable` protocol encode their `Date` properties in the default `encode(to:)` implementation.

`enum DatabaseUUIDEncodingStrategy`

`DatabaseUUIDEncodingStrategy` specifies how `EncodableRecord` types that also adopt the standard `Encodable` protocol encode their `UUID` properties in the default `encode(to:)` implementation.

### Converting a Record to a Dictionary

[`var databaseDictionary: [String : DatabaseValue]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/encodablerecord/databasedictionary)

A dictionary whose keys are the columns encoded in the `encode(to:)` method.

### Comparing Records

Returns a dictionary of values changed from the other record.

Modifies the record according to the provided `modify` closure, and returns a dictionary of changed values.

Returns a boolean indicating whether this record and the other record have the same database representation.

## Relationships

### Inherited By

- `MutablePersistableRecord`
- `PersistableRecord`

### Conforming Types

- `Record`

## See Also

### Records Protocols

`protocol FetchableRecord`

A type that can decode itself from a database row.

`protocol MutablePersistableRecord`

A type that can be persisted in the database, and mutates on insertion.

`protocol PersistableRecord`

A type that can be persisted in the database.

`protocol TableRecord`

A type that builds database queries with the Swift language instead of SQL.

- EncodableRecord
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fetchablerecord

- GRDB
- Records and the Query Interface
- FetchableRecord

Protocol

# FetchableRecord

A type that can decode itself from a database row.

protocol FetchableRecord

FetchableRecord.swift

## Overview

To conform to `FetchableRecord`, provide an implementation for the `init(row:)` initializer. This implementation is ready-made for `Decodable` types.

For example:

struct Player: FetchableRecord, Decodable {
var name: String
var score: Int
}

if let row = try Row.fetchOne(db, sql: "SELECT * FROM player") {
let player = try Player(row: row)
}

If you add conformance to `TableRecord`, the record type can generate SQL queries for you:

struct Player: FetchableRecord, TableRecord, Decodable {
var name: String
var score: Int

enum Columns {
static let name = Column("name")
static let score = Column("score")
}
}

let players = try Player.fetchAll(db)
let player = try Player.filter { $0.name == "O'Brien" }.fetchOne(db)
let players = try Player.order(\.score).fetchAll(db)

## Topics

### Initializers

`init(row: Row) throws`

Creates a record from `row`.

**Required** Default implementation provided.

### Fetching Records

Returns a cursor over all records fetched from the database.

Returns an array of all records fetched from the database.

Returns a set of all records fetched from the database.

Returns a single record fetched from the database.

### Fetching Records from Raw SQL

Returns a cursor over records fetched from an SQL query.

Returns an array of records fetched from an SQL query.

Returns a set of records fetched from an SQL query.

Returns a single record fetched from an SQL query.

### Fetching Records from a Prepared Statement

Returns a cursor over records fetched from a prepared statement.

Returns an array of records fetched from a prepared statement.

Returns a set of records fetched from a prepared statement.

Returns a single record fetched from a prepared statement.

### Fetching Records from a Request

Returns a cursor over records fetched from a fetch request.

Returns an array of records fetched from a fetch request.

Returns a set of records fetched from a fetch request.

Returns a single record fetched from a fetch request.

### Fetching Records by Primary Key

Returns a cursor over records identified by their primary keys.

Returns an array of records identified by their primary keys.

Returns a set of records identified by their primary keys.

Returns the record identified by a primary key.

Returns the record identified by a primary key, or throws an error if the record does not exist.

Returns the record identified by a unique key (the primary key or any key with a unique index on it), or throws an error if the record does not exist.

### Fetching Record by Key

Returns a cursor over records identified by the provided unique keys (primary key or any key with a unique index on it).

Returns an array of records identified by the provided unique keys (primary key or any key with a unique index on it).

Returns a set of records identified by the provided unique keys (primary key or any key with a unique index on it).

Returns the record identified by a unique key (the primary key or any key with a unique index on it).

### Configuring Row Decoding for the Standard Decodable Protocol

`static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy`

The strategy for converting column names to coding keys.

The strategy for decoding `Data` columns.

The strategy for decoding `Date` columns.

Returns the `JSONDecoder` that decodes the value for a given column.

[`static var databaseDecodingUserInfo: [CodingUserInfoKey : Any]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fetchablerecord/databasedecodinguserinfo-77jim)

Contextual information made available to the `Decodable.init(from:)` initializer.

`enum DatabaseColumnDecodingStrategy`

`DatabaseColumnDecodingStrategy` specifies how `FetchableRecord` types that also adopt the standard `Decodable` protocol look for the database columns that match their coding keys.

`enum DatabaseDataDecodingStrategy`

`DatabaseDataDecodingStrategy` specifies how `FetchableRecord` types that also adopt the standard `Decodable` protocol decode their `Data` properties.

`enum DatabaseDateDecodingStrategy`

`DatabaseDateDecodingStrategy` specifies how `FetchableRecord` types that also adopt the standard `Decodable` protocol decode their `Date` properties.

### Supporting Types

`class RecordCursor`

A cursor of records.

`class FetchableRecordDecoder`

An object that decodes fetchable records from database rows.

## Relationships

### Conforming Types

- `ColumnInfo`
- `ForeignKeyViolation`
- `Record`

## See Also

### Records Protocols

`protocol EncodableRecord`

A type that can encode itself in a database row.

`protocol MutablePersistableRecord`

A type that can be persisted in the database, and mutates on insertion.

`protocol PersistableRecord`

A type that can be persisted in the database.

`protocol TableRecord`

A type that builds database queries with the Swift language instead of SQL.

- FetchableRecord
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/persistablerecord

- GRDB
- Records and the Query Interface
- PersistableRecord

Protocol

# PersistableRecord

A type that can be persisted in the database.

protocol PersistableRecord : MutablePersistableRecord

PersistableRecord.swift

## Overview

`PersistableRecord` has non-mutating variants of `MutablePersistableRecord` methods.

## Conforming to the PersistableRecord Protocol

To conform to `PersistableRecord`, provide an implementation for the `encode(to:)` method. This implementation is ready-made for `Encodable` types.

You configure the database table where records are persisted with the `TableRecord` inherited protocol.

## Topics

### Inserting a Record

`func insert(Database, onConflict: Database.ConflictResolution?) throws`

Executes an `INSERT` statement.

`func upsert(Database) throws`

Executes an `INSERT ON CONFLICT DO UPDATE` statement.

### Inserting a Record and Fetching the Inserted Row

Executes an `INSERT RETURNING` statement, and returns a new record built from the inserted row.

Executes an `INSERT RETURNING` statement, and returns the selected columns from the inserted row.

Executes an `INSERT ON CONFLICT DO UPDATE RETURNING` statement, and returns the upserted record.

### Saving a Record

`func save(Database, onConflict: Database.ConflictResolution?) throws`

Executes an `INSERT` or `UPDATE` statement.

### Saving a Record and Fetching the Saved Row

Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and returns a new record built from the saved row.

Executes an `INSERT RETURNING` or `UPDATE RETURNING` statement, and returns the selected columns from the saved row.

### Persistence Callbacks

`func willInsert(Database) throws`

Persistence callback called before the record is inserted.

**Required** Default implementation provided.

`func didInsert(InsertionSuccess)`

Persistence callback called upon successful insertion.

## Relationships

### Inherits From

- `EncodableRecord`
- `MutablePersistableRecord`
- `TableRecord`

### Conforming Types

- `Record`

## See Also

### Records Protocols

`protocol EncodableRecord`

A type that can encode itself in a database row.

`protocol FetchableRecord`

A type that can decode itself from a database row.

`protocol MutablePersistableRecord`

A type that can be persisted in the database, and mutates on insertion.

`protocol TableRecord`

A type that builds database queries with the Swift language instead of SQL.

- PersistableRecord
- Overview
- Conforming to the PersistableRecord Protocol
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/tablerecord

- GRDB
- Records and the Query Interface
- TableRecord

Protocol

# TableRecord

A type that builds database queries with the Swift language instead of SQL.

protocol TableRecord

TableRecord.swift

## Overview

A `TableRecord` type is tied to one database table, and can build SQL queries on that table.

To build SQL queries that involve several tables, define some `Association` between two `TableRecord` types.

Most of the time, your record types will get `TableRecord` conformance through the `MutablePersistableRecord` or `PersistableRecord` protocols, which provide persistence methods.

## Topics

### Configuring the Generated SQL

`static var databaseTableName: String`

The name of the database table used to build SQL queries.

**Required** Default implementation provided.

[`static var databaseSelection: [any SQLSelectable]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/tablerecord/databaseselection-7iphs)

The columns selected by the record.

Returns the number of selected columns.

### Counting Records

Returns the number of records in the database table.

### Testing for Record Existence

Returns whether a record exists for this primary key.

Returns whether a record exists for this primary or unique key.

Returns an error that tells that the record does not exist in the database.

### Throwing Record Not Found Errors

Returns an error for a record that does not exist in the database.

### Deleting Records

Deletes all records, and returns the number of deleted records.

Deletes records identified by their primary keys, and returns the number of deleted records.

Deletes records identified by their primary or unique keys, and returns the number of deleted records.

Deletes the record identified by its primary key, and returns whether a record was deleted.

Deletes the record identified by its primary or unique key, and returns whether a record was deleted.

### Updating Records

Updates all records, and returns the number of updated records.

### Building Query Interface Requests

`TableRecord` provide convenience access to most `DerivableRequest` and `QueryInterfaceRequest` methods as static methods on the type itself.

Returns a request that can be referred to with the provided alias.

Returns a request for all records in the table.

Returns a request with the given association aggregates appended to the record selection.

Returns a request with the provided result columns appended to the record selection.

Returns a request with the columns of the eventual associated record appended to the record selection.

Returns a request with the columns of the associated record appended to the record selection. Records that do not have an associated record are discarded.

Returns a request filtered with a boolean SQL expression.

Returns a request filtered by primary key.

Returns a request filtered by primary or unique key.

Returns a request filtered with an `SQL` literal.

Returns a request filtered with an SQL string.

Returns a request filtered according to the provided association aggregate.

Returns a request that fetches all records associated with each record in this request.

Returns a request that fetches the eventual record associated with each record of this request.

Returns a request that fetches the record associated with each record in this request. Records that do not have an associated record are discarded.

Returns a request that joins each record of this request to its eventual associated record.

Returns a request that joins each record of this request to its associated record. Records that do not have an associated record are discarded.

Returns a limited request.

Returns a request filtered on records that match an `FTS3` full-text pattern.

Returns a request filtered on records that match an `FTS5` full-text pattern.

Returns an empty request that fetches no record.

Returns a request sorted according to the given SQL ordering term.

Returns a request sorted according to the given SQL ordering terms.

Returns a request sorted according to the given `SQL` literal.

Returns a request sorted according to the given SQL string.

Returns a request sorted by primary key.

Returns a request for the associated record(s).

Returns a request that selects the provided result columns.

Returns a request that selects the provided result columns, and defines the type of decoded rows.

Returns a request that selects the provided `SQL` literal.

Returns a request that selects the provided `SQL` literal, and defines the type of decoded rows.

Returns a request that selects the provided SQL string.

Returns a request that selects the provided SQL string, and defines the type of decoded rows.

Returns a request that selects the primary key.

Returns a request that embeds a common table expression.

`static var databaseComponents: Self.DatabaseComponents`

The value that provides database components to the query interface.

`associatedtype Columns = Never`

A type that defines columns.

**Required**

`associatedtype DatabaseComponents = Self.Columns.Type`

A type that provides database components to the query interface.

### Defining Associations

Creates an association to a common table expression.

Creates a `BelongsToAssociation` between `Self` and the destination `TableRecord` type.

Creates a `BelongsToAssociation` between `Self` and the destination `Table`.

Creates a `HasManyAssociation` between `Self` and the destination `TableRecord` type.

Creates a `HasManyAssociation` between `Self` and the destination `Table`.

Creates a `HasManyThroughAssociation` between `Self` and the destination `TableRecord` type.

Creates a `HasOneAssociation` between `Self` and the destination `TableRecord` type.

Creates a `HasOneAssociation` between `Self` and the destination `Table`.

Creates a `HasOneThroughAssociation` between `Self` and the destination `TableRecord` type.

### Legacy APIs

It is recommended to prefer the closure-based apis defined above, as well as record aliases over anonymous aliases.

## Relationships

### Inherited By

- `MutablePersistableRecord`
- `PersistableRecord`

### Conforming Types

- `Record`

## See Also

### Records Protocols

`protocol EncodableRecord`

A type that can encode itself in a database row.

`protocol FetchableRecord`

A type that can decode itself from a database row.

`protocol MutablePersistableRecord`

A type that can be persisted in the database, and mutates on insertion.

`protocol PersistableRecord`

A type that can be persisted in the database.

- TableRecord
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/column

- GRDB
- Records and the Query Interface
- Column

Structure

# Column

A column in a database table.

struct Column

Column.swift

## Overview

For example:

struct Player: FetchableRecord, TableRecord {
var score: Int

enum Columns {
static let score = Column("score")
}
}

try dbQueue.read { db in
// DELETE FROM player WHERE score = 0
try Player
.filter { $0.score == 0 }
.deleteAll(db)

// SELECT * FROM player ORDER BY score DESC LIMIT 10
let bestPlayers = try Player
.order(\.score)
.limit(10)
.fetchAll(db)

// SELECT MAX(score) FROM player
let maximumScore = try Player
.select({ max($0.score) }, as: Int.self)
.fetchOne(db)
}

## Topics

### Standard Columns

`static let rowID: Column`

The hidden rowID column.

`static let rank: Column`

The `FTS5` rank column.

### Creating A Column

`init(String)`

Creates a `Column` given its name.

`init(some CodingKey)`

Creates a `Column` given a `CodingKey`.

### Instance Properties

`var name: String`

## Relationships

### Conforms To

- `ColumnExpression`
- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`
- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Expressions

`struct JSONColumn`

A JSON column in a database table.

`struct SQLExpression`

An SQL expression.

- Column
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/jsoncolumn

- GRDB
- JSON Support
- JSONColumn

Structure

# JSONColumn

A JSON column in a database table.

struct JSONColumn

JSONColumn.swift

## Overview

`JSONColumn` has benefits over `Column` for database columns that contain JSON strings.

It behaves like a regular `Column`, with all extra conveniences and behaviors of `SQLJSONExpressible`.

For example, the sample code below directly accesses the “countryCode” key of the “address” JSON column:

struct Player: Codable {
var id: Int64
var name: String
var address: Address
}

struct Address: Codable {
var street: String
var city: String
var countryCode: String
}

extension Player: FetchableRecord, PersistableRecord {
enum Columns {
static let id = Column(CodingKeys.id)
static let name = Column(CodingKeys.name)
static let address = JSONColumn(CodingKeys.address) // JSONColumn
}
}

try dbQueue.write { db in
// In a real app, table creation should happen in a migration.
try db.create(table: "player") { t in
t.autoIncrementedPrimaryKey("id")
t.column("name", .text).notNull()
t.column("address", .jsonText).notNull()
}

// Fetch all country codes
// SELECT DISTINCT address ->> 'countryCode' FROM player
let countryCodes: [String] = try Player
.select({ $0.address["countryCode"] }, as: String.self)
.distinct()
.fetchAll(db)
}

## Topics

### Initializers

`init(String)`

Creates a `JSONColumn` given its name.

`init(some CodingKey)`

Creates a `JSONColumn` given a `CodingKey`.

### Instance Properties

`var name: String`

## Relationships

### Conforms To

- `ColumnExpression`
- `SQLExpressible`
- `SQLJSONExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`
- `Swift.Sendable`

## See Also

### JSON Values

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

- JSONColumn
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlexpression

- GRDB
- Records and the Query Interface
- SQLExpression

Structure

# SQLExpression

An SQL expression.

struct SQLExpression

SQLExpression.swift

## Overview

`SQLExpression` is an opaque representation of an SQL expression. You generally build `SQLExpression` from other expressions. For example:

// Values
1000.sqlExpression
"O'Brien".sqlExpression

// Computed expressions
Column("score") + Column("bonus")
(0...1000).contains(Column("score"))

// Literal expression
SQL("IFNULL(name, \(defaultName))").sqlExpression

// Subquery
Player.select(max(Column("score"))).sqlExpression

`SQLExpression` is better used as the return type of a function. For function arguments, prefer the `SQLExpressible` or `SQLSpecificExpressible` protocols. For example:

SQL("DATE(\(value))").sqlExpression
}

struct Player: TableRecord {
enum Columns {
static let createdAt = Column("createdAt")
}
}

// SELECT * FROM "player" WHERE DATE("createdAt") = '2020-01-23'
let request = Player.filter { date($0.createdAt) == "2020-01-23" }

Related SQLite documentation:

## Topics

### Structures

`struct AssociativeBinaryOperator`

An associative binary SQL operator, such as `+`, `*`, `AND`, etc.

## Relationships

### Conforms To

- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`
- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Expressions

`struct Column`

A column in a database table.

`struct JSONColumn`

A JSON column in a database table.

- SQLExpression
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression

- GRDB
- Records and the Query Interface
- CommonTableExpression

Structure

# CommonTableExpression

A common table expression that can be used with the GRDB query interface.

CommonTableExpression.swift

## Topics

### Initializers

[`init(recursive: Bool, named: String, columns: [String]?, literal: SQL)`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression/init(recursive:named:columns:literal:)-4nr63)

Creates a common table expression from an SQL _literal_.

[`init(recursive: Bool, named: String, columns: [String]?, literal: SQL)`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression/init(recursive:named:columns:literal:)-7vimx)

[`init(recursive: Bool, named: String, columns: [String]?, request: some SQLSubqueryable)`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression/init(recursive:named:columns:request:)-35myd)

Creates a common table expression from a request.

[`init(recursive: Bool, named: String, columns: [String]?, request: some SQLSubqueryable)`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression/init(recursive:named:columns:request:)-69rlb)

[`init(recursive: Bool, named: String, columns: [String]?, sql: String, arguments: StatementArguments)`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression/init(recursive:named:columns:sql:arguments:)-1ft4x)

Creates a common table expression from an SQL string and optional arguments.

[`init(recursive: Bool, named: String, columns: [String]?, sql: String, arguments: StatementArguments)`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression/init(recursive:named:columns:sql:arguments:)-8hnp2)

### Instance Properties

`var tableName: String`

The table name of the common table expression.

### Instance Methods

Creates a request for all rows of the common table expression.

Creates an association to a table that you can join or include in another request.

Creates an association to a table record that you can join or include in another request.

Creates an association to a common table expression that you can join or include in another request.

An SQL expression that checks the inclusion of an expression in a common table expression.

## See Also

### Requests

`struct QueryInterfaceRequest`

A request that builds SQL queries with Swift.

`struct Table`

A `Table` builds database queries with the Swift language instead of SQL.

- CommonTableExpression
- Topics
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/queryinterfacerequest

- GRDB
- Records and the Query Interface
- QueryInterfaceRequest

Structure

# QueryInterfaceRequest

A request that builds SQL queries with Swift.

QueryInterfaceRequest.swift

## Overview

You build a `QueryInterfaceRequest` from a `TableRecord` type, or a `Table` instance. For example:

struct Player: TableRecord, FetchableRecord, DecodableRecord {
enum Columns {
static let name = Column("name")
static let score = Column("score")
}
}

try dbQueue.read { db in
// SELECT * FROM player
// WHERE name = 'O''Reilly'
// ORDER BY score DESC
let request = Player
.filter { $0.name == "O'Reilly" }
.order(\.score.desc)
let players: [Player] = try request.fetchAll(db)
}

Most features of `QueryInterfaceRequest` come from the protocols it conforms to. In particular:

- **Fetching methods** are defined by `FetchRequest`.

- **Request building methods** are defined by `DerivableRequest`.

## Topics

### Instance Methods

Returns whether the requests does not match any row in the database.

Returns a limited request.

### Changing The Type of Fetched Results

Returns a request that performs an identical database query, but decodes database rows with `type`.

Defines the result columns, and defines the type of decoded rows.

Defines the result columns with an `SQL` literal, and defines the type of decoded rows.

Defines the result columns with an SQL string, and defines the type of decoded rows.

Returns a request that selects the primary key.

### Batch Delete

Deletes matching rows, and returns the number of deleted rows.

Executes a `DELETE RETURNING` statement and returns the set of deleted ids.

Returns a cursor over the records deleted by a `DELETE RETURNING` statement.

Executes a `DELETE RETURNING` statement and returns the array of deleted records.

Executes a `DELETE RETURNING` statement and returns the set of deleted records.

Returns a `DELETE RETURNING` prepared statement.

### Batch Update

Updates matching rows, and returns the number of updated rows.

Returns a cursor over the records updated by an `UPDATE RETURNING` statement.

Execute an `UPDATE RETURNING` statement and returns the array of updated records.

Execute an `UPDATE RETURNING` statement and returns the set of updated records.

Returns an `UPDATE RETURNING` prepared statement.

`struct ColumnAssignment`

A `ColumnAssignment` assigns a value to a column.

### Legacy APIs

It is recommended to prefer the closure-based apis defined above.

### Type Aliases

`typealias DatabaseComponents`

## Relationships

### Conforms To

- `AggregatingRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `DatabaseRegionConvertible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `DerivableRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `FetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `FilteredRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `JoinableRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `OrderedRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLExpressible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLOrderingTerm`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSelectable`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSpecificExpressible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSubqueryable`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SelectionRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `Swift.Copyable`
- `Swift.Sendable`
- `TableRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `TypedRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

## See Also

### Requests

`struct CommonTableExpression`

A common table expression that can be used with the GRDB query interface.

`struct Table`

A `Table` builds database queries with the Swift language instead of SQL.

- QueryInterfaceRequest
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/table

- GRDB
- Records and the Query Interface
- Table

Structure

# Table

A `Table` builds database queries with the Swift language instead of SQL.

Table.swift

## Overview

A `Table` instance is similar to a `TableRecord` type. You will use one when the other is impractical or impossible to use.

For example:

let table = Table("player")
try dbQueue.read { db in

}

## Topics

### Creating a Table

`init(String)`

Creates a `Table`.

### Instance Properties

`var tableName: String`

The table name.

### Counting Rows

Returns the number of rows in the database table.

### Testing for Row Existence

Returns whether a row exists for this primary key.

Returns whether a row exists for this primary or unique key.

### Deleting Rows

Deletes all rows, and returns the number of deleted rows.

Deletes rows identified by their primary keys, and returns the number of deleted rows.

Deletes rows identified by their primary or unique keys, and returns the number of deleted rows.

Deletes the row identified by its primary key, and returns whether a row was deleted.

Deletes the row identified by its primary or unique keys, and returns whether a row was deleted.

### Updating Rows

Updates all rows, and returns the number of updated rows.

### Building Query Interface Requests

`Table` provide convenience access to most `DerivableRequest` and `QueryInterfaceRequest` methods.

Returns a request that can be referred to with the provided record alias.

Returns a request that can be referred to with the provided anonymous alias.

Returns a request for all rows of the table.

Returns a request with the provided result columns appended to the table columns.

Returns a request with the given association aggregates appended to the table colums.

Returns a request with the columns of the eventual associated row appended to the table columns.

Returns a request with the columns of the associated row appended to the table columns. Rows that do not have an associated row are discarded.

Returns a request filtered with a boolean SQL expression.

Returns a request filtered by primary key.

Returns a request filtered by primary or unique key.

Returns a request filtered with an `SQL` literal.

Returns a request filtered with an SQL string.

Returns a request filtered according to the provided association aggregate.

Returns a request that fetches all rows associated with each row in this request.

Returns a request that fetches the eventual row associated with each row of this request.

Returns a request that fetches the row associated with each row in this request. Rows that do not have an associated row are discarded.

Returns a request that joins each row of this request to its eventual associated row.

Returns a request that joins each row of this request to its associated row. Rows that do not have an associated row are discarded.

Returns a limited request.

Returns an empty request that fetches no row.

Returns a request sorted according to the given SQL ordering terms.

Returns a request sorted according to the given `SQL` literal.

Returns a request sorted according to the given SQL string.

Returns a request sorted by primary key.

Returns a request that selects the provided result columns.

Returns a request that selects the provided result columns, and defines the type of decoded rows.

Returns a request that selects the provided `SQL` literal.

Returns a request that selects the provided `SQL` literal, and defines the type of decoded rows.

Returns a request that selects the provided SQL string.

Returns a request that selects the provided SQL string, and defines the type of decoded rows.

Returns a request that selects the primary key.

Returns a request that embeds a common table expression.

### Defining Associations

Creates an association to a common table expression.

Creates a `BelongsToAssociation` between this table and the destination `TableRecord` type.

Creates a `BelongsToAssociation` between this table and the destination `Table`.

Creates a `HasManyAssociation` between this table and the destination `TableRecord` type.

Creates a `HasManyAssociation` between this table and the destination `Table`.

Creates a `HasManyThroughAssociation` between this table and the destination type.

Creates a `HasOneAssociation` between this table and the destination `TableRecord` type.

Creates a `HasOneAssociation` between this table and the destination `Table`.

Creates a `HasOneThroughAssociation` between this table and the destination type.

### Fetching Database Rows

Returns a cursor over all rows fetched from the database.

Returns an array of all rows fetched from the database.

Returns a set of all rows fetched from the database.

Returns a single row fetched from the database.

### Fetching Database Values

Returns a cursor over fetched values.

Returns an array of fetched values.

Returns a set of fetched values.

Returns a single fetched value.

### Fetching Records

Returns a cursor over all records fetched from the database.

Returns an array of all records fetched from the database.

Returns a set of all records fetched from the database.

Returns a single record fetched from the database.

### Type Aliases

`typealias DatabaseComponents`

## Relationships

### Conforms To

- `DatabaseRegionConvertible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `Swift.Copyable`
- `Swift.Sendable`

## See Also

### Requests

`struct CommonTableExpression`

A common table expression that can be used with the GRDB query interface.

`struct QueryInterfaceRequest`

A request that builds SQL queries with Swift.

- Table
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/association

- GRDB
- Records and the Query Interface
- Association

Protocol

# Association

A type that defines a connection between two tables.

protocol Association : DerivableRequest, Sendable

Association.swift

## Overview

`Association` feeds methods of the `JoinableRequest` protocol. They are built from a `TableRecord` type, or a `Table` instance.

## Topics

### Instance Methods

Returns an association with the given key.

**Required** Default implementations provided.

### Associations To One

`struct BelongsToAssociation`

Thes `BelongsToAssociation` sets up a one-to-one connection from a record type to another record type, such as each instance of the declaring record “belongs to” an instance of the other record.

`struct HasOneAssociation`

The `HasOneAssociation` indicates a one-to-one connection between two record types, such as each instance of the declaring record “has one” instances of the other record.

`struct HasOneThroughAssociation`

The `HasOneThroughAssociation` sets up a one-to-one connection with another record. This association indicates that the declaring record can be matched with one instance of another record by proceeding through a third record.

`protocol AssociationToOne`

An association that defines a to-one connection.

### Associations To Many

`struct HasManyAssociation`

The `HasManyAssociation` indicates a one-to-many connection between two record types, such as each instance of the declaring record “has many” instances of the other record.

`struct HasManyThroughAssociation`

The `HasManyThroughAssociation` is often used to set up a many-to-many connection with another record. This association indicates that the declaring record can be matched with zero or more instances of another record by proceeding through a third record.

`protocol AssociationToMany`

An association that defines a to-many connection.

### Associations to Common Table Expressions

`struct JoinAssociation`

The `JoinAssociation` joins common table expression to regular tables or other common table expressions.

### Supporting Types

`struct ForeignKey`

A `ForeignKey` defines on which columns an association between two tables is established.

`struct Inflections`

A type that controls GRDB string inflections.

### Associated Types

`associatedtype OriginRowDecoder`

The record type at the origin of the association.

**Required**

## Relationships

### Inherits From

- `AggregatingRequest`
- `DerivableRequest`
- `FilteredRequest`
- `JoinableRequest`
- `OrderedRequest`
- `SelectionRequest`
- `Swift.Sendable`
- `TableRequest`
- `TypedRequest`

### Inherited By

- `AssociationToMany`
- `AssociationToOne`

### Conforming Types

- `BelongsToAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasManyAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasManyThroughAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasOneAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasOneThroughAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `JoinAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- Association
- Overview
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recorderror

- GRDB
- Records and the Query Interface
- RecordError

Enumeration

# RecordError

A record error.

enum RecordError

TableRecord.swift

## Overview

`RecordError` is thrown by `MutablePersistableRecord` types when an `update` method could not find any row to update:

do {
try player.update(db)
} catch let RecordError.recordNotFound(databaseTableName: table, key: key) {
print("Key \(key) was not found in table \(table).")
}

`RecordError` is also thrown by `FetchableRecord` types when a `find` method does not find any record:

do {
let player = try Player.find(db, id: 42)
} catch let RecordError.recordNotFound(databaseTableName: table, key: key) {
print("Key \(key) was not found in table \(table).")
}

You can create `RecordError` instances with the `recordNotFound(_:id:)` method and its variants.

## Topics

### Enumeration Cases

[`case recordNotFound(databaseTableName: String, key: [String : DatabaseValue])`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recorderror/recordnotfound(databasetablename:key:))

A record does not exist in the database.

## Relationships

### Conforms To

- `Swift.Copyable`
- `Swift.CustomStringConvertible`
- `Swift.Error`
- `Swift.Sendable`

## See Also

### Errors

`typealias PersistenceError` Deprecated

- RecordError
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/persistenceerror



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/columnexpression

- GRDB
- Records and the Query Interface
- ColumnExpression

Protocol

# ColumnExpression

A type that represents a column in a database table.

protocol ColumnExpression : SQLSpecificExpressible

Column.swift

## Topics

### Standard Columns

`static var rowID: Column`

The hidden rowID column.

### Deriving SQL Expressions

`var detached: SQLExpression`

An SQL expression that refers to an aliased column ( `expression AS alias`).

A matching SQL expression with the `MATCH` SQL operator.

### Creating Column Assignments

`var noOverwrite: ColumnAssignment`

An assignment that does not modify this column.

Returns an assignment of this column to an SQL expression.

### Operators

Creates an assignment that applies a bitwise and.

Creates an assignment that multiplies by an SQL expression.

Creates an assignment that adds an SQL expression.

Creates an assignment that subtracts an SQL expression.

Creates an assignment that applies a bitwise or.

Creates an assignment that divides by an SQL expression.

Creates an assignment that applies a bitwise left shift.

`static func >>= (Self, some SQLExpressible) -> ColumnAssignment`

Creates an assignment that applies a bitwise right shift.

### Instance Properties

`var name: String`

The column name.

**Required** Default implementation provided.

## Relationships

### Inherits From

- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`

### Conforming Types

- `Column`
- `JSONColumn`

## See Also

### Supporting Types

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

- ColumnExpression
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/derivablerequest

- GRDB
- Records and the Query Interface
- DerivableRequest

Protocol

# DerivableRequest

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

RequestProtocols.swift

## Overview

Most features of `DerivableRequest` come from the protocols it inherits from.

## Topics

### Instance Methods

Returns a request that can be referred to with the provided record alias.

`class TableAlias`

A TableAlias identifies a table in a request.

### The WITH Clause

Embeds a common table expression.

**Required** Default implementation provided.

### The SELECT Clause

Appends a result column to the selected columns.

Appends result columns to the selected columns.

Returns a request which returns distinct rows.

Defines the result column.

Defines the result columns.

Defines the result columns with an `SQL` literal.

Defines the result columns with an SQL string.

### The WHERE Clause

Returns `self`: a request that fetches all rows from this request.

Filters the fetched rows with a boolean SQL expression.

Filters by primary key.

Filters by primary or unique key.

Filters the fetched rows with an `SQL` literal.

Filters the fetched rows with an SQL string.

Filters rows that match an `FTS3` full-text pattern.

Filters rows that match an `FTS5` full-text pattern.

Returns an empty request that fetches no row.

### The GROUP BY and HAVING Clauses

Returns an aggregate request grouped on the given SQL expression.

Returns an aggregate request grouped on the given SQL expressions.

Returns an aggregate request grouped on an `SQL` literal.

Returns an aggregate request grouped on an SQL string.

Returns an aggregate request grouped on the primary key.

Filters the aggregated groups with a boolean SQL expression.

Filters the aggregated groups with an `SQL` literal.

Filters the aggregated groups with an SQL string.

### The ORDER BY Clause

Sorts the fetched rows according to the given SQL ordering term.

Sorts the fetched rows according to the given SQL ordering terms.

Sorts the fetched rows according to the given `SQL` literal.

Sorts the fetched rows according to the given SQL string.

Sorts the fetched rows according to the primary key.

Returns a request with reversed ordering.

Returns a request without any ordering.

Returns a request with a stable order.

### Associations

Appends the columns of the eventual associated record to the selected columns.

Appends the columns of the associated record to the selected columns. Records that do not have an associated record are discarded.

Appends association aggregates to the selected columns.

Filters the fetched records with an association aggregate.

Returns a request that fetches all records associated with each record in this request.

Returns a request that fetches the eventual record associated with each record of this request.

Returns a request that fetches the record associated with each record in this request. Records that do not have an associated record are discarded.

Returns a request that joins each record of this request to its eventual associated record.

Returns a request that joins each record of this request to its associated record. Records that do not have an associated record are discarded.

### Supporting Types

`protocol AggregatingRequest`

A request that can aggregate database rows.

`protocol FilteredRequest`

A request that can filter database rows.

`protocol JoinableRequest`

A request that can join and prefetch associations.

`protocol OrderedRequest`

A request that can sort database rows.

`protocol SelectionRequest`

A request that can define the selected columns.

`protocol TableRequest`

A request that feeds from a database table

`protocol TypedRequest`

A request that knows how to decode database rows.

### Legacy APIs

It is recommended to prefer the closure-based apis defined above, as well as record aliases over anonymous aliases.

Returns a request that can be referred to with the provided anonymous alias.

## Relationships

### Inherits From

- `AggregatingRequest`
- `FilteredRequest`
- `JoinableRequest`
- `OrderedRequest`
- `SelectionRequest`
- `TableRequest`
- `TypedRequest`

### Inherited By

- `Association`
- `AssociationToMany`
- `AssociationToOne`

### Conforming Types

- `BelongsToAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasManyAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasManyThroughAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasOneAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `HasOneThroughAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `JoinAssociation`
Conforms when `Origin` conforms to `Copyable`, `Origin` conforms to `Escapable`, `Destination` conforms to `Copyable`, and `Destination` conforms to `Escapable`.

- `QueryInterfaceRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

## See Also

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

- DerivableRequest
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlexpressible

- GRDB
- Records and the Query Interface
- SQLExpressible

Protocol

# SQLExpressible

A type that can be used as an SQL expression.

protocol SQLExpressible

SQLExpression.swift

## Overview

Related SQLite documentation

## Topics

### Instance Properties

`var sqlExpression: SQLExpression`

Returns an SQL expression.

**Required** Default implementations provided.

### Type Properties

`static var rowID: Column`

The hidden rowID column.

## Relationships

### Inherited By

- `ColumnExpression`
- `DatabaseValueConvertible`
- `FetchRequest`
- `SQLJSONExpressible`
- `SQLSpecificExpressible`
- `SQLSubqueryable`

### Conforming Types

- `AdaptedFetchRequest`
Conforms when `Base` conforms to `FetchRequest`.

- `AnyFetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `AnySQLJSONExpressible`
- `Bool`
- `CGFloat`
- `Column`
- `Data`
- `DatabaseDateComponents`
- `DatabaseValue`
- `Date`
- `Decimal`
- `Double`
- `FTS3Pattern`
- `FTS5Pattern`
- `Float`
- `IndexInfo.Origin`
- `Int`
- `Int16`
- `Int32`
- `Int64`
- `Int8`
- `JSONColumn`
- `NSData`
- `NSDate`
- `NSNull`
- `NSNumber`
- `NSString`
- `NSURL`
- `NSUUID`
- `Optional`
Conforms when `Wrapped` conforms to `SQLExpressible`.

- `QueryInterfaceRequest`
- `SQL`
- `SQLDateModifier`
- `SQLExpression`
- `SQLRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSubquery`
- `String`
- `UInt`
- `UInt16`
- `UInt32`
- `UInt64`
- `UInt8`
- `URL`
- `UUID`

## See Also

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

- SQLExpressible
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqljsonexpressible

- GRDB
- JSON Support
- SQLJSONExpressible

Protocol

# SQLJSONExpressible

A type of SQL expression that is interpreted as a JSON value.

protocol SQLJSONExpressible : SQLSpecificExpressible

SQLJSONExpressible.swift

## Overview

JSON values that conform to `SQLJSONExpressible` have two purposes:

- They provide Swift APIs for accessing their JSON subcomponents at the SQL level.

- When used in a JSON-building function such as `jsonArray(_:)` or `jsonObject(_:)`, they are parsed and interpreted as JSON, not as plain strings.

To build a JSON value, create a `JSONColumn`, or call the `asJSON` property of any other expression.

For example, here are some JSON values:

// JSON columns:
JSONColumn("info")
Column("info").asJSON

// The JSON array [1, 2, 3]:
"[1, 2, 3]".databaseValue.asJSON

// A JSON value that will trigger a
// "malformed JSON" SQLite error when
// parsed by SQLite:
"{foo".databaseValue.asJSON

The expressions below are not JSON values:

// A plain column:
Column("info")

// Plain strings:
"[1, 2, 3]"
"{foo"

## Access JSON subcomponents

JSON values provide access to the `->` and `->>` SQL operators and other SQLite JSON functions:

let info = JSONColumn("info")

// SELECT info ->> 'firstName' FROM player
// → 'Arthur'
let firstName = try Player
.select(info["firstName"], as: String.self)
.fetchOne(db)

// SELECT info ->> 'address' FROM player
// → '{"street":"Rue de Belleville","city":"Paris"}'
let address = try Player
.select(info["address"], as: String.self)
.fetchOne(db)

## Build JSON objects and arrays from JSON values

When used in a JSON-building function such as `jsonArray(_:)` or `jsonObject(_:)`, JSON values are parsed and interpreted as JSON, not as plain strings.

In the example below, we can see how the `JSONColumn` is interpreted as JSON, while the `Column` with the same name is interpreted as a plain string:

let elements: [any SQLExpressible] = [\
JSONColumn("address"),\
Column("address"),\
]

let array = Database.jsonArray(elements)

// SELECT JSON_ARRAY(JSON(address), address) FROM player
// → '[{"country":"FR"},"{\"country\":\"FR\"}"]'

.select(array, as: String.self)
.fetchOne(db)

## Topics

### Accessing JSON subcomponents

The `->>` SQL operator.

The `JSON_EXTRACT` SQL function.

### Supporting Types

`struct AnySQLJSONExpressible`

A type-erased `SQLJSONExpressible`.

## Relationships

### Inherits From

- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`

### Conforming Types

- `AnySQLJSONExpressible`
- `JSONColumn`

## See Also

### JSON Values

`struct JSONColumn`

A JSON column in a database table.

- SQLJSONExpressible
- Overview
- Access JSON subcomponents
- Build JSON objects and arrays from JSON values
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlspecificexpressible

- GRDB
- Records and the Query Interface
- SQLSpecificExpressible

Protocol

# SQLSpecificExpressible

A database-specific type that can be used as an SQL expression.

protocol SQLSpecificExpressible : SQLExpressible, SQLOrderingTerm, SQLSelectable

SQLExpression.swift

## Overview

`SQLSpecificExpressible` is the protocol for all database-specific types that can be turned into an SQL expression. Types whose existence is not purely dedicated to the database should adopt the `SQLExpressible` protocol instead.

For example, `Column` is a type that only exists to help you build requests, and it adopts `SQLSpecificExpressible`.

On the other side, `Int` adopts `SQLExpressible`.

## Topics

### Applying a Collation

Returns a collated expression.

### SQL Functions & Operators

See also JSON functions in JSON Support.

The `ABS` SQL function.

The `AVG` SQL aggregate function.

`var capitalized: SQLExpression`

An SQL expression that calls the Foundation `String.capitalized` property.

The `CAST` SQL function.

The `COALESCE` SQL function.

The `COUNT` SQL function.

The `COUNT(DISTINCT)` SQL function.

The `DATETIME` SQL function.

The `JULIANDAY` SQL function.

The `LENGTH` SQL function.

The `LIKE` SQL operator.

`var localizedCapitalized: SQLExpression`

An SQL expression that calls the Foundation `String.localizedCapitalized` property.

`var localizedLowercased: SQLExpression`

An SQL expression that calls the Foundation `String.localizedLowercase` property.

`var localizedUppercased: SQLExpression`

An SQL expression that calls the Foundation `String.localizedUppercase` property.

`var lowercased: SQLExpression`

An SQL expression that calls the Swift `String.lowercased()` method.

The `MIN` SQL multi-argument function.

The `MIN` SQL aggregate function.

The `MAX` SQL multi-argument function.

The `MAX` SQL aggregate function.

The `SUM` SQL aggregate function.

The `TOTAL` SQL aggregate function.

`var uppercased: SQLExpression`

An SQL expression that calls the Swift `String.uppercased()` method.

`enum SQLDateModifier`

A date modifier for SQLite date functions.

### Interpreting an expression as JSON

`var asJSON: AnySQLJSONExpressible`

Returns an expression that is interpreted as a JSON value.

### Creating Ordering Terms

`var asc: SQLOrdering`

An ordering term for ascending order (nulls first).

`var ascNullsLast: SQLOrdering`

An ordering term for ascending order (nulls last).

`var desc: SQLOrdering`

An ordering term for descending order (nulls last).

`var descNullsFirst: SQLOrdering`

An ordering term for descending order (nulls first).

### Creating Result Columns

Returns an aliased result column.

Returns an aliased column with the same name as the coding key.

### Operators

A negated logical SQL expression.

Compares two SQL expressions.

The `IS NOT` SQL operator.

The `AND` SQL operator.

The `&` SQL operator.

The `*` SQL operator.

The `+` SQL operator.

The `-` SQL operator.

The `=` SQL operator.

The `IS` SQL operator.

The `/` SQL operator.

The `|` SQL operator.

The `<` SQL operator.

The `<=` SQL operator.

`static func >> (Self, some SQLExpressible) -> SQLExpression`

The `>>` SQL operator.

The `OR` SQL operator.

`static func >> (some SQLExpressible, Self) -> SQLExpression`

`static func >> (Self, some SQLSpecificExpressible) -> SQLExpression`

The `<<` SQL operator.

The `IFNULL` SQL function.

The `~` SQL operator.

## Relationships

### Inherits From

- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`

### Inherited By

- `ColumnExpression`
- `FetchRequest`
- `SQLJSONExpressible`
- `SQLSubqueryable`

### Conforming Types

- `AdaptedFetchRequest`
Conforms when `Base` conforms to `FetchRequest`.

- `AnyFetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `AnySQLJSONExpressible`
- `Column`
- `DatabaseValue`
- `JSONColumn`
- `Optional`
Conforms when `Wrapped` conforms to `SQLSpecificExpressible`.

- `QueryInterfaceRequest`
- `SQL`
- `SQLDateModifier`
- `SQLExpression`
- `SQLRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSubquery`

## See Also

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

- SQLSpecificExpressible
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlsubqueryable

- GRDB
- Records and the Query Interface
- SQLSubqueryable

Protocol

# SQLSubqueryable

A type that can be used as SQL subquery.

protocol SQLSubqueryable : SQLSpecificExpressible

SQLSubquery.swift

## Overview

Related SQLite documentation

## Topics

### Supporting Types

`struct SQLSubquery`

An SQL subquery.

### Instance Properties

`var sqlSubquery: SQLSubquery`

**Required**

### Instance Methods

Returns an expression that checks the inclusion of the expression in the subquery.

Returns an expression that is true if and only if the subquery would return one or more rows.

## Relationships

### Inherits From

- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`

### Inherited By

- `FetchRequest`

### Conforming Types

- `AdaptedFetchRequest`
Conforms when `Base` conforms to `FetchRequest`.

- `AnyFetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `QueryInterfaceRequest`
- `SQLRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSubquery`

## See Also

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

- SQLSubqueryable
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlorderingterm

- GRDB
- Records and the Query Interface
- SQLOrderingTerm

Protocol

# SQLOrderingTerm

A type that can be used as an SQL ordering term.

protocol SQLOrderingTerm

SQLOrdering.swift

## Overview

Related SQLite documentation

## Topics

### Supporting Type

`struct SQLOrdering`

An SQL ordering term.

### Instance Properties

`var sqlOrdering: SQLOrdering`

Returns an SQL ordering.

**Required** Default implementations provided.

## Relationships

### Inherited By

- `ColumnExpression`
- `FetchRequest`
- `SQLJSONExpressible`
- `SQLSpecificExpressible`
- `SQLSubqueryable`

### Conforming Types

- `AdaptedFetchRequest`
Conforms when `Base` conforms to `FetchRequest`.

- `AnyFetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `AnySQLJSONExpressible`
- `Column`
- `DatabaseValue`
- `JSONColumn`
- `Optional`
Conforms when `Wrapped` conforms to `SQLOrderingTerm`.

- `QueryInterfaceRequest`
- `SQL`
- `SQLDateModifier`
- `SQLExpression`
- `SQLOrdering`
- `SQLRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSubquery`

## See Also

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLSelectable`

A type that can be used as SQL result columns.

- SQLOrderingTerm
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlselectable

- GRDB
- Records and the Query Interface
- SQLSelectable

Protocol

# SQLSelectable

A type that can be used as SQL result columns.

protocol SQLSelectable

SQLSelection.swift

## Overview

Related SQLite documentation

## Topics

### Standard Selections

`static var rowID: Column`

The hidden rowID column.

`static var allColumns: AllColumns`

All columns of the requested table.

All columns of the requested table, excluding the provided columns.

### Supporting Types

`struct AllColumns`

`AllColumns` is the `*` in `SELECT *`.

`struct AllColumnsExcluding`

`AllColumnsExcluding` selects all columns in a database table, but the ones you specify.

`struct SQLSelection`

An SQL result column.

### Instance Properties

`var sqlSelection: SQLSelection`

Returns an SQL selection.

**Required** Default implementations provided.

## Relationships

### Inherited By

- `ColumnExpression`
- `FetchRequest`
- `SQLJSONExpressible`
- `SQLSpecificExpressible`
- `SQLSubqueryable`

### Conforming Types

- `AdaptedFetchRequest`
Conforms when `Base` conforms to `FetchRequest`.

- `AllColumns`
- `AllColumnsExcluding`
- `AnyFetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `AnySQLJSONExpressible`
- `Column`
- `DatabaseValue`
- `JSONColumn`
- `Optional`
Conforms when `Wrapped` conforms to `SQLSelectable`.

- `QueryInterfaceRequest`
- `SQL`
- `SQLDateModifier`
- `SQLExpression`
- `SQLRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSelection`
- `SQLSubquery`

## See Also

### Supporting Types

`protocol ColumnExpression`

A type that represents a column in a database table.

`protocol DerivableRequest`

`DerivableRequest` is the base protocol for `QueryInterfaceRequest` and `Association`.

`protocol SQLExpressible`

A type that can be used as an SQL expression.

`protocol SQLJSONExpressible`

A type of SQL expression that is interpreted as a JSON value.

`protocol SQLSpecificExpressible`

A database-specific type that can be used as an SQL expression.

`protocol SQLSubqueryable`

A type that can be used as SQL subquery.

`protocol SQLOrderingTerm`

A type that can be used as an SQL ordering term.

- SQLSelectable
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/record

- GRDB
- Records and the Query Interface
- Record

Class

# Record

A base class for types that can be fetched and persisted in the database.

class Record

Record.swift

## Overview

## Topics

### Creating Record Instances

`init()`

Creates a Record.

`init(row: Row) throws`

Creates a Record from a row.

### Encoding a Database Row

`func encode(to: inout PersistenceContainer) throws`

Encodes the record into the provided persistence container.

### Changes Tracking

[`var databaseChanges: [String : DatabaseValue?]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/record/databasechanges)

A dictionary of changes that have not been saved.

`var hasDatabaseChanges: Bool`

A boolean value indicating whether the record has changes that have not been saved.

If the record has been changed, executes an `UPDATE` statement so that those changes and only those changes are saved in the database.

### Persistence Callbacks

`func willSave(Database) throws`

Called before the record is updated or inserted.

`func willInsert(Database) throws`

Called before the record is inserted.

Called before the record is updated.

`func willDelete(Database) throws`

Called before the record is deleted.

`func didSave(PersistenceSuccess)`

Called upon successful update or insertion.

`func didInsert(InsertionSuccess)`

Called upon successful insertion.

`func didUpdate(PersistenceSuccess)`

Called upon successful update.

`func didDelete(deleted: Bool)`

Called upon successful deletion.

Called around the record update or insertion.

Called around the record insertion.

Called around the record update.

Called around the destruction of the record.

### Type Properties

[`class var databaseSelection: [any SQLSelectable]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/record/databaseselection-6hiji)

The columns selected by the record.

`class var databaseTableName: String`

The name of the database table used to build SQL queries.

`class var persistenceConflictPolicy: PersistenceConflictPolicy`

## Relationships

### Conforms To

- `EncodableRecord`
- `FetchableRecord`
- `MutablePersistableRecord`
- `PersistableRecord`
- `Swift.Copyable`
- `TableRecord`

- Record
- Overview
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/encodablerecord)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fetchablerecord)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/persistablerecord)



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/tablerecord)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/column)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/jsoncolumn)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlexpression)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/commontableexpression)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/queryinterfacerequest)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/table)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/association)



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/recorderror)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/persistenceerror)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/columnexpression)



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/derivablerequest)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/association).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlexpressible)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqljsonexpressible)



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlspecificexpressible)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlsubqueryable)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlorderingterm)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlselectable)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/record)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator

- GRDB
- Migrations
- DatabaseMigrator

Structure

# DatabaseMigrator

A `DatabaseMigrator` registers and applies database migrations.

struct DatabaseMigrator

DatabaseMigrator.swift

## Overview

For an overview of database migrations and `DatabaseMigrator` usage, see Migrations.

## Topics

### Creating a DatabaseMigrator

`init()`

A new migrator.

### Registering Migrations

Registers a migration.

`enum ForeignKeyChecks`

Controls how a migration handle foreign keys constraints.

### Configuring a DatabaseMigrator

`var eraseDatabaseOnSchemaChange: Bool`

A boolean value indicating whether the migrator recreates the whole database from scratch if it detects a change in the definition of migrations.

Returns a migrator that disables foreign key checks in all newly registered migrations.

### Migrating a Database

Schedules unapplied migrations for execution, and returns immediately.

`func migrate(any DatabaseWriter) throws`

Runs all unapplied migrations, in the same order as they were registered.

`func migrate(any DatabaseWriter, upTo: String) throws`

Runs all unapplied migrations, in the same order as they were registered, up to the target migration identifier (included).

Returns a Publisher that asynchronously migrates a database.

### Querying Migrations

[`var migrations: [String]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator/migrations)

The list of registered migration identifiers, in the same order as they have been registered.

Returns the applied migration identifiers, even unregistered ones.

Returns the identifiers of registered and applied migrations, in the order of registration.

Returns the identifiers of registered and completed migrations, in the order of registration.

A boolean value indicating whether the database refers to unregistered migrations.

A boolean value indicating whether all registered migrations, and only registered migrations, have been applied.

### Detecting Schema Changes

Returns a boolean value indicating whether the migrator detects a change in the definition of migrations.

## Relationships

### Conforms To

- `Swift.Sendable`

- DatabaseMigrator
- Overview
- Topics
- Relationships

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator/migrate(_:)

#app-main)

- GRDB
- Migrations
- DatabaseMigrator
- migrate(\_:)

Instance Method

# migrate(\_:)

Runs all unapplied migrations, in the same order as they were registered.

func migrate(_ writer: any DatabaseWriter) throws

DatabaseMigrator.swift

## Parameters

`writer`

A DatabaseWriter.

## Discussion

## See Also

### Migrating a Database

Schedules unapplied migrations for execution, and returns immediately.

`func migrate(any DatabaseWriter, upTo: String) throws`

Runs all unapplied migrations, in the same order as they were registered, up to the target migration identifier (included).

Returns a Publisher that asynchronously migrates a database.

- migrate(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator/erasedatabaseonschemachange



---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/checkforeignkeys()

#app-main)

- GRDB
- The Database Schema
- Integrity Checks
- checkForeignKeys()

Instance Method

# checkForeignKeys()

Throws an error if there exists a foreign key violation in the database.

func checkForeignKeys() throws

Database+Schema.swift

## Discussion

On the first foreign key violation found in the database, this method throws a `DatabaseError` with extended code `SQLITE_CONSTRAINT_FOREIGNKEY`.

If you are looking for the list of foreign key violations, prefer `foreignKeyViolations()` instead.

## See Also

### Integrity Checks

`func checkForeignKeys(in: String, in: String?) throws`

Throws an error if there exists a foreign key violation in the table.

Returns a cursor over foreign key violations in the database.

Returns a cursor over foreign key violations in the table.

`struct ForeignKeyViolation`

A foreign key violation.

- checkForeignKeys()
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/checkforeignkeys(in:in:)

#app-main)

- GRDB
- The Database Schema
- Integrity Checks
- checkForeignKeys(in:in:)

Instance Method

# checkForeignKeys(in:in:)

Throws an error if there exists a foreign key violation in the table.

func checkForeignKeys(
in tableName: String,
in schemaName: String? = nil
) throws

Database+Schema.swift

## Discussion

When `schemaName` is not specified, known schemas are checked in SQLite resolution order and the first matching table is used.

On the first foreign key violation found in the table, this method throws a `DatabaseError` with extended code `SQLITE_CONSTRAINT_FOREIGNKEY`.

If you are looking for the list of foreign key violations, prefer `foreignKeyViolations(in:in:)` instead.

## See Also

### Integrity Checks

`func checkForeignKeys() throws`

Throws an error if there exists a foreign key violation in the database.

Returns a cursor over foreign key violations in the database.

Returns a cursor over foreign key violations in the table.

`struct ForeignKeyViolation`

A foreign key violation.

- checkForeignKeys(in:in:)
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/foreignkeyviolation

- GRDB
- The Database Schema
- Integrity Checks
- ForeignKeyViolation

Structure

# ForeignKeyViolation

A foreign key violation.

struct ForeignKeyViolation

Database+Schema.swift

## Overview

You get instances of `ForeignKeyViolation` from the `Database` methods `foreignKeyViolations()` and `foreignKeyViolations(in:in:)` methods.

For example:

try dbQueue.read {
let violations = try db.foreignKeyViolations()
while let violation = try violations.next() {
// The name of the table that contains the `REFERENCES` clause
violation.originTable

// The rowid of the row that contains the invalid `REFERENCES` clause, or
// nil if the origin table is a `WITHOUT ROWID` table.
violation.originRowID

// The name of the table that is referred to.
violation.destinationTable

// The id of the specific foreign key constraint that failed. This id
// matches `ForeignKeyInfo.id`. See `Database.foreignKeys(on:)` for more
// information.
violation.foreignKeyId

// Plain description:
// "FOREIGN KEY constraint violation - from player to team, in rowid 1"
String(describing: violation)

// Rich description:
// "FOREIGN KEY constraint violation - from player(teamId) to team(id),
// in [id:1 teamId:2 name:"O'Brien" score:1000]"
try violation.failureDescription(db)

// Turn violation into a DatabaseError
throw violation.databaseError(db)
}
}

Related SQLite documentation:

## Topics

### Instance Properties

`var destinationTable: String`

The name of the table that is referred to.

`var foreignKeyId: Int`

The id of the foreign key constraint that failed.

`var originRowID: Int64?`

The rowid of the row that contains the foreign key violation.

`var originTable: String`

The name of the table that contains the foreign key.

### Instance Methods

Converts the violation into a `DatabaseError`.

A precise description of the foreign key violation.

## Relationships

### Conforms To

- `FetchableRecord`
- `Swift.Copyable`
- `Swift.CustomStringConvertible`
- `Swift.Sendable`

## See Also

### Integrity Checks

`func checkForeignKeys() throws`

Throws an error if there exists a foreign key violation in the database.

`func checkForeignKeys(in: String, in: String?) throws`

Throws an error if there exists a foreign key violation in the table.

Returns a cursor over foreign key violations in the database.

Returns a cursor over foreign key violations in the table.

- ForeignKeyViolation
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseconnections)),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator/migrate(_:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator/migrate(_:)).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasemigrator/erasedatabaseonschemachange)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/checkforeignkeys())

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/database/checkforeignkeys(in:in:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/foreignkeyviolation).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/statement

- GRDB
- SQL, Prepared Statements, Rows, and Values
- Statement

Class

# Statement

A prepared statement.

final class Statement

Statement.swift

## Overview

Prepared statements let you execute an SQL query several times, with different arguments if needed.

Reusing prepared statements is a performance optimization technique because SQLite parses and analyses the SQL query only once, when the prepared statement is created.

## Building Prepared Statements

Build a prepared statement with the `makeStatement(sql:)` method:

try dbQueue.write { db in
let insertStatement = try db.makeStatement(sql: """
INSERT INTO player (name, score) VALUES (:name, :score)
""")

let selectStatement = try db.makeStatement(sql: """
SELECT * FROM player WHERE name = ?
""")
}

The `?` and colon-prefixed keys like `:name` in the SQL query are the statement arguments. Set the values for those arguments with arrays or dictionaries of database values, or `StatementArguments` instances:

insertStatement.arguments = ["name": "Arthur", "score": 1000]
selectStatement.arguments = ["Arthur"]

Alternatively, the `makeStatement(literal:)` method creates prepared statements with support for SQL Interpolation:

let insertStatement = try db.makeStatement(literal: "INSERT ...")
let selectStatement = try db.makeStatement(literal: "SELECT ...")
// ~~~~~~~

The `makeStatement` methods throw an error of code `SQLITE_MISUSE` (21) if the SQL query contains multiple statements joined with a semicolon. See Parsing Multiple Prepared Statements from a Single SQL String below.

## Executing Prepared Statements and Fetching Values

Prepared statements can be executed:

try insertStatement.execute()

To fetch rows and values from a prepared statement, use a fetching method of `Row`, `DatabaseValueConvertible`, or `FetchableRecord`:

let players = try Player.fetchCursor(selectStatement) // A Cursor of Player
let players = try Player.fetchAll(selectStatement) // [Player]

// ~~~~~~ or Row, Int, String, Date, etc.

Arguments can be set at the moment of the statement execution:

try insertStatement.execute(arguments: ["name": "Arthur", "score": 1000])
let player = try Player.fetchOne(selectStatement, arguments: ["Arthur"])

## Caching Prepared Statements

When the same query will be used several times in the lifetime of an application, one may feel a natural desire to cache prepared statements.

Don’t cache statements yourself.

Instead, use the `cachedStatement(sql:)` method. GRDB does all the hard caching and memory management:

let statement = try db.cachedStatement(sql: "INSERT ...")

The variant `cachedStatement(literal:)` supports SQL Interpolation:

let statement = try db.cachedStatement(literal: "INSERT ...")

Should a cached prepared statement throw an error, don’t reuse it. Instead, reload one from the cache.

## Parsing Multiple Prepared Statements from a Single SQL String

To build multiple statements joined with a semicolon, use `allStatements(sql:arguments:)`:

let statements = try db.allStatements(sql: """
INSERT INTO player (name, score) VALUES (?, ?);
INSERT INTO player (name, score) VALUES (?, ?);
""", arguments: ["Arthur", 100, "O'Brien", 1000])
while let statement = try statements.next() {
try statement.execute()
}

The variant `allStatements(literal:)` supports SQL Interpolation:

let statements = try db.allStatements(literal: """
INSERT INTO player (name, score) VALUES (\("Arthur"), \(100));
INSERT INTO player (name, score) VALUES (\("O'Brien"), \(1000));
""")
// An alternative way to iterate all statements
try statements.forEach { statement in
try statement.execute()
}

The results of multiple `SELECT` statements can be joined into a single `Cursor`. This is the GRDB version of the `sqlite3_exec()` function:

let statements = try db.allStatements(sql: """
SELECT ...;
SELECT ...;
""")
let players = try statements.flatMap { statement in
try Player.fetchCursor(statement)
}
for let player = try players.next() {
print(player.name)
}

The `SQLStatementCursor` returned from `allStatements` can be turned into a regular Swift array, but in this case make sure all individual statements can compile even if the previous ones were not executed:

// OK: Array of statements
let statements = try Array(db.allStatements(sql: """
INSERT ...;
UPDATE ...;
"""))

// FAILURE: Can't build an array of statements since the INSERT won't
// compile until CREATE TABLE is executed.
let statements = try Array(db.allStatements(sql: """
CREATE TABLE player ...;
INSERT INTO player ...;
"""))

## Topics

### Executing a Prepared Statement

`func execute(arguments: StatementArguments?) throws`

Executes the prepared statement.

### Arguments

`var arguments: StatementArguments`

The statement arguments.

`func setArguments(StatementArguments) throws`

Validates and sets the statement arguments.

`func setUncheckedArguments(StatementArguments)`

Set arguments without any validation. Trades safety for performance.

`func validateArguments(StatementArguments) throws`

Throws a `DatabaseError` of code `SQLITE_ERROR` if the provided arguments do not provide all values expected by the statement.

`struct StatementArguments`

An instance of `StatementArguments` provides the values for argument placeholders in a prepared `Statement`.

### Statement Informations

`var columnCount: Int`

The number of columns in the resulting rows.

[`var columnNames: [String]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/statement/columnnames)

The column names, ordered from left to right.

`var databaseRegion: DatabaseRegion`

The database region that the statement looks into.

Returns the index of the leftmost column with the given name.

`var isReadonly: Bool`

A boolean value indicating if the prepared statement makes no direct changes to the content of the database file.

`var sql: String`

The SQL query.

`let sqliteStatement: SQLiteStatement`

The raw SQLite statement, suitable for the SQLite C API.

`typealias SQLiteStatement`

A raw SQLite statement, suitable for the SQLite C API.

## Relationships

### Conforms To

- `Swift.Copyable`
- `Swift.CustomStringConvertible`

## See Also

### Fundamental Database Types

`class Row`

A database row.

`struct DatabaseValue`

A value stored in a database table.

`protocol DatabaseCursor`

A cursor that lazily iterates the results of a prepared `Statement`.

- Statement
- Overview
- Building Prepared Statements
- Executing Prepared Statements and Fetching Values
- Caching Prepared Statements
- Parsing Multiple Prepared Statements from a Single SQL String
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasecursor

- GRDB
- SQL, Prepared Statements, Rows, and Values
- DatabaseCursor

Protocol

# DatabaseCursor

A cursor that lazily iterates the results of a prepared `Statement`.

Statement.swift

## Overview

To get a `DatabaseCursor` instance, use one of the `fetchCursor` methods. For example:

- A cursor of `Row` built from a prepared `Statement`:

try dbQueue.read { db in
let statement = try db.makeStatement(sql: "SELECT * FROM player")
let rows = try Row.fetchCursor(statement)
while let row = try rows.next() {
let id: Int64 = row["id"]
let name: String = row["name"]
}
}

- A cursor of `Int` built from an SQL string (see `DatabaseValueConvertible`):

try dbQueue.read { db in
let sql = "SELECT score FROM player"
let scores = try Int.fetchCursor(db, sql: sql)
while let score = try scores.next() {
print(score)
}
}

- A cursor of `Player` records built from a request (see `FetchableRecord` and `FetchRequest`):

try dbQueue.read { db in
let request = Player.all()
let players = try request.fetchCursor(db)
while let player = try players.next() {
print(player.name, player.score)
}
}

A database cursor is valid only during the current database access (read or write). Do not store or escape a cursor for later use.

A database cursor resets its underlying prepared statement with `sqlite3_reset` when the cursor is created, and when it is deallocated. Don’t share the same prepared statement between two cursors!

## Topics

### Instance Properties

`var arguments: StatementArguments`

The statement arguments.

`var columnCount: Int`

The number of columns in the resulting rows.

[`var columnNames: [String]`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasecursor/columnnames)

The column names, ordered from left to right.

`var databaseRegion: DatabaseRegion`

The database region that the cursor looks into.

`var sql: String`

The SQL query.

## Relationships

### Inherits From

- `Cursor`

### Conforming Types

- `DatabaseValueCursor`
- `FastDatabaseValueCursor`
- `RecordCursor`
- `RowCursor`

## See Also

### Fundamental Database Types

`class Statement`

A prepared statement.

`class Row`

A database row.

`struct DatabaseValue`

A value stored in a database table.

- DatabaseCursor
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/row

- GRDB
- SQL, Prepared Statements, Rows, and Values
- Row

Class

# Row

A database row.

final class Row

Row.swift

## Overview

To get `Row` instances, you will generally fetch them from a `Database` instance. For example:

try dbQueue.read { db in
let rows = try Row.fetchCursor(db, sql: """
SELECT * FROM player
""")
while let row = try rows.next() {
let id: Int64 = row["id"]
let name: String = row["name"]
}
}

## Topics

### Creating Rows

`convenience init()`

Creates an empty row.

[`convenience init([String : (any DatabaseValueConvertible)?])`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/row/init(_:)-5uezw)

Creates a row from a dictionary of database values.

[`convenience init?([AnyHashable : Any])`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/row/init(_:)-65by6)

Creates a row from a dictionary.

### Copying a Row

Returns an immutable copy of the row.

### Row Informations

The names of columns in the row, from left to right.

`var containsNonNullValue: Bool`

Returns a boolean value indicating if the row contains one value this is not `NULL`.

`let count: Int`

The number of columns in the row.

The database values in the row, from left to right.

Returns whether the row has one column with the given name (case-insensitive).

Returns whether the row has a `NULL` value at given index.

### Accessing Row Values by Int Index

Returns `Int64`, `Double`, `String`, `Data` or nil, depending on the value stored at the given index.

Returns the value at given index, converted to the requested type.

Calls the given closure with the `Data` at given index.

Returns the optional `Data` at given index.

Deprecated

### Accessing Row Values by Column Name

Returns `Int64`, `Double`, `String`, `Data` or nil, depending on the value stored at the given column.

Returns the value at given column, converted to the requested type.

Returns the first non-null value, if any. Identical to SQL `COALESCE` function.

Calls the given closure with the `Data` at the given column.

Returns the optional `Data` at given column.

### Accessing Row Values by Column

### Row Scopes & Associated Rows

`var prefetchedRows: Row.PrefetchedRowsView`

A view on the prefetched associated rows.

`var scopes: Row.ScopesView`

A view on the scopes defined by row adapters.

`var scopesTree: Row.ScopesTreeView`

A view on the scopes tree defined by row adapters.

`var unadapted: Row`

The raw row fetched from the database.

`var unscoped: Row`

The row, without any scope of prefetched rows.

Returns the eventual record associated to the given key.

Returns the record associated to the given key.

Returns a collection of prefetched records associated to the given association key.

Returns the set of prefetched records associated to the given association key.

`struct PrefetchedRowsView`

`struct ScopesTreeView`

`struct ScopesView`

### Fetching Rows from Raw SQL

Returns a cursor over rows fetched from an SQL query.

Returns an array of rows fetched from an SQL query.

Returns a set of rows fetched from an SQL query.

Returns a single row fetched from an SQL query.

### Fetching Rows from a Prepared Statement

Returns a cursor over rows fetched from a prepared statement.

Returns an array of rows fetched from a prepared statement.

Returns a set of rows fetched from a prepared statement.

Returns a single row fetched from a prepared statement.

### Fetching Rows from a Request

Returns a cursor over rows fetched from a fetch request.

Returns an array of rows fetched from a fetch request.

Returns a set of rows fetched from a fetch request.

Returns a single row fetched from a fetch request.

### Row as RandomAccessCollection

Returns the (column, value) pair at given index.

`struct Index`

An index to a (column, value) pair in a `Row`.

### Adapting Rows

`protocol RowAdapter`

A type that helps two incompatible row interfaces working together.

### Errors

`struct RowDecodingError`

A decoding error thrown when decoding a database row.

### Supporting Types

`class RowCursor`

A cursor of raw database rows.

## Relationships

### Conforms To

- `Swift.BidirectionalCollection`
- `Swift.Collection`
- `Swift.Copyable`
- `Swift.CustomDebugStringConvertible`
- `Swift.CustomStringConvertible`
- `Swift.Equatable`
- `Swift.ExpressibleByDictionaryLiteral`
- `Swift.Hashable`
- `Swift.RandomAccessCollection`
- `Swift.Sequence`

## See Also

### Fundamental Database Types

`class Statement`

A prepared statement.

`struct DatabaseValue`

A value stored in a database table.

`protocol DatabaseCursor`

A cursor that lazily iterates the results of a prepared `Statement`.

- Row
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlrequest

- GRDB
- SQL, Prepared Statements, Rows, and Values
- SQLRequest

Structure

# SQLRequest

An SQL request that can decode database rows.

SQLRequest.swift

## Overview

`SQLRequest` allows you to safely embed raw values in your SQL, without any risk of syntax errors or SQL injection:

extension Player: FetchableRecord {

"SELECT * FROM player WHERE name = \(name)"
}

"SELECT MAX(score) FROM player"
}
}

try dbQueue.read { db in
let players = try Player.filter(name: "O'Brien").fetchAll(db) // [Player]
let maxScore = try Player.maximumScore().fetchOne(db) // Int?
}

An `SQLRequest` can be created from a string literal or interpolation, as in the above examples, and from the initializers documented below.

## Topics

### Creating an SQL Request from a Literal Value

`init(stringLiteral: String)`

Creates an `SQLRequest` from the given literal SQL string.

`init(unicodeScalarLiteral: String)`

`init(extendedGraphemeClusterLiteral: String)`

### Creating an SQL Request from an Interpolation

`init(stringInterpolation: SQLInterpolation)`

### Creating an SQL Request from an SQL Literal

`init(literal: SQL, adapter: (any RowAdapter)?, cached: Bool)`

Creates a request from an `SQL` literal.

Creates a request of database rows, from an `SQL` literal.

### Creating an SQL Request from an SQL String

`init(sql: String, arguments: StatementArguments, adapter: (any RowAdapter)?, cached: Bool)`

Creates a request from an SQL string.

Creates a request of database rows, from an SQL string.

### Instance Properties

`var adapter: (any RowAdapter)?`

The row adapter.

## Relationships

### Conforms To

- `DatabaseRegionConvertible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `FetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLExpressible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLOrderingTerm`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSelectable`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSpecificExpressible`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLSubqueryable`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `Swift.Copyable`
- `Swift.ExpressibleByExtendedGraphemeClusterLiteral`
- `Swift.ExpressibleByStringInterpolation`
- `Swift.ExpressibleByStringLiteral`
- `Swift.ExpressibleByUnicodeScalarLiteral`
- `Swift.Sendable`

## See Also

### SQL Literals and Requests

`struct SQL`

An SQL literal.

Return as many question marks separated with commas as the _count_ argument.

- SQLRequest
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasevalue

- GRDB
- SQL, Prepared Statements, Rows, and Values
- DatabaseValue

Structure

# DatabaseValue

A value stored in a database table.

struct DatabaseValue

DatabaseValue.swift

## Overview

To get `DatabaseValue` instances, you can:

- Fetch `DatabaseValue` from a `Database` instace:

try dbQueue.read { db in
let dbValue = try DatabaseValue.fetchOne(db, sql: """
SELECT name FROM player
""")
}

- Extract `DatabaseValue` from a database `Row`:

try dbQueue.read { db in
if let row = try Row.fetchOne(db, sql: """
SELECT name FROM player
""")
{
let dbValue = row[0] as DatabaseValue
}
}

- Use the `databaseValue` property on a `DatabaseValueConvertible` value:

let dbValue = DatabaseValue.null
let dbValue = 1.databaseValue
let dbValue = "Arthur".databaseValue
let dbValue = Date().databaseValue

Related SQLite documentation:

## Topics

### Creating a DatabaseValue

`init?(value: Any)`

Creates a `DatabaseValue` from any value.

`init(sqliteStatement: SQLiteStatement, index: CInt)`

Creates a `DatabaseValue` initialized from a raw SQLite statement pointer.

`static let null: DatabaseValue`

The NULL DatabaseValue.

### Accessing the SQLite storage

`var isNull: Bool`

A boolean value indicating is the database value is `NULL`.

`let storage: DatabaseValue.Storage`

The SQLite storage.

`enum Storage`

A value stored in a database table, with its exact SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).

## Relationships

### Conforms To

- `DatabaseValueConvertible`
- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`
- `StatementBinding`
- `Swift.Copyable`
- `Swift.CustomStringConvertible`
- `Swift.Equatable`
- `Swift.Hashable`
- `Swift.Sendable`

## See Also

### Fundamental Database Types

`class Statement`

A prepared statement.

`class Row`

A database row.

`protocol DatabaseCursor`

A cursor that lazily iterates the results of a prepared `Statement`.

- DatabaseValue
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sql

- GRDB
- SQL, Prepared Statements, Rows, and Values
- SQL

Structure

# SQL

An SQL literal.

struct SQL

SQL.swift

## Overview

`SQL` literals allow you to safely embed raw values in your SQL, without any risk of syntax errors or SQL injection. For example:

try dbQueue.write { db in
let name: String = "O'Brien"
let id: Int64 = 42
let query: SQL = "UPDATE player SET name = \(name) WHERE id = \(id)"

// UPDATE player SET name = 'O''Brien' WHERE id = 42
try db.execute(literal: query)
}

## Topics

### Creating an SQL Literal from a Literal Value

`init(stringLiteral: String)`

Creates an `SQL` literal from the given literal SQL string.

`init(unicodeScalarLiteral: String)`

`init(extendedGraphemeClusterLiteral: String)`

### Creating an SQL Literal from an Interpolation

`init(stringInterpolation: SQLInterpolation)`

`struct SQLInterpolation`

### Creating an SQL Literal from an SQL String

`init(sql: String, arguments: StatementArguments)`

Creates an `SQL` literal from a plain SQL string, and eventual arguments.

### Creating an SQL Literal from an SQL Expression

`init(some SQLSpecificExpressible)`

Creates an `SQL` literal from an SQL expression.

### Concatenating SQL Literals

`func append(literal: SQL)`

Appends an `SQL` literal to the receiver.

`func append(sql: String, arguments: StatementArguments)`

Appends a plain SQL string to the receiver, and eventual arguments.

### Operators

Returns the `SQL` literal produced by the concatenation of two literals.

`static func += (inout SQL, SQL)`

### Instance Properties

`var isEmpty: Bool`

Returns true if this literal generates an empty SQL string

### Instance Methods

Turn a `SQL` literal into raw SQL and arguments.

## Relationships

### Conforms To

- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`
- `Swift.Copyable`
- `Swift.ExpressibleByExtendedGraphemeClusterLiteral`
- `Swift.ExpressibleByStringInterpolation`
- `Swift.ExpressibleByStringLiteral`
- `Swift.ExpressibleByUnicodeScalarLiteral`
- `Swift.Sendable`

## See Also

### SQL Literals and Requests

`struct SQLRequest`

An SQL request that can decode database rows.

Return as many question marks separated with commas as the _count_ argument.

- SQL
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasequestionmarks(count:)

#app-main)

- GRDB
- SQL, Prepared Statements, Rows, and Values
- databaseQuestionMarks(count:)

Function

# databaseQuestionMarks(count:)

Return as many question marks separated with commas as the _count_ argument.

Utils.swift

## Discussion

databaseQuestionMarks(count: 3) // "?,?,?"

## See Also

### SQL Literals and Requests

`struct SQL`

An SQL literal.

`struct SQLRequest`

An SQL request that can decode database rows.

- databaseQuestionMarks(count:)
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasedatecomponents

- GRDB
- SQL, Prepared Statements, Rows, and Values
- DatabaseDateComponents

Structure

# DatabaseDateComponents

A database value that holds date components.

struct DatabaseDateComponents

DatabaseDateComponents.swift

## Topics

### Initializers

`init(DateComponents, format: DatabaseDateComponents.Format)`

Creates a DatabaseDateComponents from a DateComponents and a format.

### Instance Properties

`let dateComponents: DateComponents`

The date components

`let format: DatabaseDateComponents.Format`

The database format

### Enumerations

`enum Format`

The SQLite formats for date components.

## Relationships

### Conforms To

- `DatabaseValueConvertible`
- `SQLExpressible`
- `StatementBinding`
- `StatementColumnConvertible`
- `Swift.Copyable`
- `Swift.Decodable`
- `Swift.Encodable`
- `Swift.Sendable`

## See Also

### Database Values

`protocol DatabaseValueConvertible`

A type that can convert itself into and out of a database value.

`protocol StatementColumnConvertible`

A type that can decode itself from the low-level C interface to SQLite results.

- DatabaseDateComponents
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasevalueconvertible

- GRDB
- SQL, Prepared Statements, Rows, and Values
- DatabaseValueConvertible

Protocol

# DatabaseValueConvertible

A type that can convert itself into and out of a database value.

protocol DatabaseValueConvertible : SQLExpressible, StatementBinding

DatabaseValueConvertible.swift

## Overview

A `DatabaseValueConvertible` type supports conversion to and from database values (null, integers, doubles, strings, and blobs). `DatabaseValueConvertible` is adopted by `Bool`, `Int`, `String`, `Date`, etc.

## Conforming to the DatabaseValueConvertible Protocol

To conform to `DatabaseValueConvertible`, implement the two requirements `fromDatabaseValue(_:)` and `databaseValue`. Do not customize the `fromMissingColumn()` requirement. If your type `MyValue` conforms, then the conformance of the optional type `MyValue?` is automatic.

The implementation of `fromDatabaseValue` must return nil if the type can not be decoded from the raw database value. This nil value will have GRDB throw a decoding error accordingly.

For example:

struct EvenInteger {
let value: Int // Guaranteed even

init?(_ value: Int) {
guard value.isMultiple(of: 2) else {
return nil // Not an even number
}
self.value = value
}
}

extension EvenInteger: DatabaseValueConvertible {
var databaseValue: DatabaseValue {
value.databaseValue
}

guard let value = Int.fromDatabaseValue(dbValue) else {
return nil // Not an integer
}
return EvenInteger(value) // Nil if not even
}
}

### Built-in RawRepresentable support

`DatabaseValueConvertible` implementation is ready-made for `RawRepresentable` types whose raw value is itself `DatabaseValueConvertible`, such as enums:

enum Grape: String {
case chardonnay, merlot, riesling
}

// Encodes and decodes `Grape` as a string in the database:
extension Grape: DatabaseValueConvertible { }

### Built-in Codable support

`DatabaseValueConvertible` is also ready-made for `Codable` types, which are automatically coded and decoded from JSON arrays and objects:

struct Color: Codable {
var red: Double
var green: Double
var blue: Double
}

// Encodes and decodes `Color` as a JSON object in the database:
extension Color: DatabaseValueConvertible { }

By default, such codable value types are encoded and decoded with the standard JSONEncoder and JSONDecoder. `Data` values are handled with the `.base64` strategy, `Date` with the `.millisecondsSince1970` strategy, and non conforming floats with the `.throw` strategy.

To customize the JSON format, provide an explicit implementation for the `DatabaseValueConvertible` requirements, or implement these two methods:

protocol DatabaseValueConvertible {

}

### Adding support for the Tagged library

Tagged is a popular library that makes it possible to enhance the type-safety of our programs with dedicated wrappers around basic types. For example:

import Tagged

struct Player: Identifiable {
// Thanks to Tagged, Player.ID can not be mismatched with Team.ID or
// Award.ID, even though they all wrap strings.

var name: String
var score: Int
}

Applications that use both Tagged and GRDB will want to add those lines somewhere:

import GRDB
import Tagged

// Add database support to Tagged values
extension Tagged: @retroactive SQLExpressible where RawValue: SQLExpressible { }
extension Tagged: @retroactive StatementBinding where RawValue: StatementBinding { }
extension Tagged: @retroactive StatementColumnConvertible where RawValue: StatementColumnConvertible { }
extension Tagged: @retroactive DatabaseValueConvertible where RawValue: DatabaseValueConvertible { }

This makes it possible to use `Tagged` values in all the expected places:

let id: Player.ID = ...
let player = try Player.find(db, id: id)

## Optimized Values

For extra performance, custom value types can conform to both `DatabaseValueConvertible` and `StatementColumnConvertible`. This extra protocol grants raw access to the low-level C SQLite interface when decoding values.

extension EvenInteger: StatementColumnConvertible {
init?(sqliteStatement: SQLiteStatement, index: CInt) {
let int64 = sqlite3_column_int64(sqliteStatement, index)
guard let value = Int(exactly: int64) else {
return nil // Does not fit Int (probably a 32-bit architecture)
}
self.init(value) // Nil if not even
}
}

This extra conformance is not required: only aim at the low-level C interface if you have identified a performance issue after profiling your application!

## Topics

### Creating a Value

Creates an instance with the specified database value.

**Required** Default implementations provided.

Creates an instance from a missing column, if possible.

**Required** Default implementation provided.

### Accessing the DatabaseValue

`var databaseValue: DatabaseValue`

A database value.

### Configuring the JSON format for the standard Decodable protocol

Returns the `JSONDecoder` that decodes the value.

Returns the `JSONEncoder` that encodes the value.

### Fetching Values from Raw SQL

Returns a cursor over values fetched from an SQL query.

Returns an array of values fetched from an SQL query.

Returns a set of values fetched from an SQL query.

Returns a single value fetched from an SQL query.

### Fetching Values from a Prepared Statement

Returns a cursor over values fetched from a prepared statement.

Returns an array of values fetched from a prepared statement.

Returns a set of values fetched from a prepared statement.

Returns a single value fetched from a prepared statement.

### Fetching Values from a Request

Returns a cursor over values fetched from a fetch request.

Returns an array of values fetched from a fetch request.

Returns a set of values fetched from a fetch request.

Returns a single value fetched from a fetch request.

### Supporting Types

`class DatabaseValueCursor`

A cursor of database values.

`protocol StatementBinding`

A type that can bind a statement argument.

## Relationships

### Inherits From

- `SQLExpressible`
- `StatementBinding`

### Conforming Types

- `Bool`
- `CGFloat`
- `Data`
- `DatabaseDateComponents`
- `DatabaseValue`
- `Date`
- `Decimal`
- `Double`
- `FTS3Pattern`
- `FTS5Pattern`
- `Float`
- `IndexInfo.Origin`
- `Int`
- `Int16`
- `Int32`
- `Int64`
- `Int8`
- `NSData`
- `NSDate`
- `NSNull`
- `NSNumber`
- `NSString`
- `NSURL`
- `NSUUID`
- `Optional`
Conforms when `Wrapped` conforms to `DatabaseValueConvertible`.

- `String`
- `UInt`
- `UInt16`
- `UInt32`
- `UInt64`
- `UInt8`
- `URL`
- `UUID`

## See Also

### Database Values

`struct DatabaseDateComponents`

A database value that holds date components.

`protocol StatementColumnConvertible`

A type that can decode itself from the low-level C interface to SQLite results.

- DatabaseValueConvertible
- Overview
- Conforming to the DatabaseValueConvertible Protocol
- Built-in RawRepresentable support
- Built-in Codable support
- Adding support for the Tagged library
- Optimized Values
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/statementcolumnconvertible

- GRDB
- SQL, Prepared Statements, Rows, and Values
- StatementColumnConvertible

Protocol

# StatementColumnConvertible

A type that can decode itself from the low-level C interface to SQLite results.

protocol StatementColumnConvertible

StatementColumnConvertible.swift

## Overview

`StatementColumnConvertible` is adopted by `Bool`, `Int`, `String`, `Date`, and most common values.

When a type conforms to both `DatabaseValueConvertible` and `StatementColumnConvertible`, GRDB can apply some optimization whenever direct access to SQLite is possible. For example:

// Optimized
let scores = Int.fetchAll(db, sql: "SELECT score FROM player")

let rows = try Row.fetchCursor(db, sql: "SELECT * FROM player")
while let row = try rows.next() {
// Optimized
let int: Int = row[0]
let name: String = row[1]
}

struct Player: FetchableRecord {
var name: String
var score: Int

init(row: Row) {
// Optimized
name = row["name"]
score = row["score"]
}
}

To conform to `StatementColumnConvertible`, provide a custom implementation of `init(sqliteStatement:index:)`. This implementation is ready-made for `RawRepresentable` types whose `RawValue` is `StatementColumnConvertible`.

Related SQLite documentation:

## Topics

### Creating a Value

`init?(sqliteStatement: SQLiteStatement, index: CInt)`

Creates an instance from a raw SQLite statement pointer, if possible.

**Required** Default implementation provided.

### Fetching Values from Raw SQL

Returns a cursor over values fetched from an SQL query.

Returns an array of values fetched from an SQL query.

Returns a set of values fetched from an SQL query.

Returns a single value fetched from an SQL query.

### Fetching Values from a Prepared Statement

Returns a cursor over values fetched from a prepared statement.

Returns an array of values fetched from a prepared statement.

Returns a set of values fetched from a prepared statement.

Returns a single value fetched from a prepared statement.

### Fetching Values from a Request

Returns a cursor over values fetched from a fetch request.

Returns an array of values fetched from a fetch request.

Returns a set of values fetched from a fetch request.

Returns a single value fetched from a fetch request.

### Supporting Types

`class FastDatabaseValueCursor`

A cursor of database values.

## Relationships

### Conforming Types

- `Bool`
- `Data`
- `DatabaseDateComponents`
- `Date`
- `Decimal`
- `Double`
- `Float`
- `Int`
- `Int16`
- `Int32`
- `Int64`
- `Int8`
- `Optional`
Conforms when `Wrapped` conforms to `StatementColumnConvertible`.

- `String`
- `UInt`
- `UInt16`
- `UInt32`
- `UInt64`
- `UInt8`
- `UUID`

## See Also

### Database Values

`struct DatabaseDateComponents`

A database value that holds date components.

`protocol DatabaseValueConvertible`

A type that can convert itself into and out of a database value.

- StatementColumnConvertible
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/cursor

- GRDB
- SQL, Prepared Statements, Rows, and Values
- Cursor

Protocol

# Cursor

A type that supplies the values of some external resource, one at a time.

Cursor.swift

## Overview

To iterate over the elements of a cursor, use a `while` loop:

while let element = try cursor.next() {
print(element)
}

## Relationship with standard Sequence and IteratorProtocol

Cursors share traits with lazy sequences and iterators from the Swift standard library. Differences are:

- Cursor types are classes, and have a lifetime.

- Cursor iteration may throw errors.

- A cursor can not be repeated.

The protocol comes with default implementations for many operations similar to those defined by Swift’s Sequence protocol: `contains`, `dropFirst`, `dropLast`, `drop(while:)`, `enumerated`, `filter`, `first`, `flatMap`, `forEach`, `joined`, `joined(separator:)`, `max`, `max(by:)`, `min`, `min(by:)`, `map`, `prefix`, `prefix(while:)`, `reduce`, `reduce(into:)`, `suffix`.

## Topics

### Supporting Types

`class AnyCursor`

A type-erased cursor.

`class DropFirstCursor`

A `Cursor` that consumes and drops n elements from an underlying `Base` cursor before possibly returning the first available element.

`class DropWhileCursor`

A `Cursor` whose elements consist of the elements that follow the initial consecutive elements of some `Base` cursor that satisfy a given predicate.

`class EnumeratedCursor`

An enumeration of the elements of a cursor.

`class FilterCursor`

A `Cursor` whose elements consist of the elements of some `Base` cursor that also satisfy a given predicate.

`class FlattenCursor`

A `Cursor` consisting of all the elements contained in each segment contained in some `Base` cursor.

`class MapCursor`

A `Cursor` whose elements consist of those in a `Base` cursor passed through a transform function returning Element.

`class PrefixCursor`

A `Cursor` that only consumes up to `n` elements from an underlying `Base` cursor.

`class PrefixWhileCursor`

A `Cursor` whose elements consist of the initial consecutive elements of some `Base` cursor that satisfy a given predicate.

### Associated Types

`associatedtype Element`

The type of element traversed by the cursor.

**Required**

### Instance Properties

`var isEmpty: Bool`

Returns a Boolean value indicating whether the cursor does not contain any element.

### Instance Methods

`func compactMap<ElementOfResult>((Self.Element) throws -> ElementOfResult?) -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult>`

Returns a cursor over the concatenated non-nil results of mapping transform over this cursor.

Returns a Boolean value indicating whether the cursor contains the given element.

Returns a Boolean value indicating whether the cursor contains an element that satisfies the given predicate.

Returns a cursor that skips any initial elements that satisfy `predicate`.

Returns a cursor containing all but the first element of the cursor.

Returns a cursor containing all but the given number of initial elements.

Returns an array containing all but the last element of the cursor.

Returns an array containing all but the given number of final elements.

Returns a cursor of pairs (n, x), where n represents a consecutive integer starting at zero, and x represents an element of the cursor.

Returns the elements of the cursor that satisfy the given predicate.

Returns the first element of the cursor that satisfies the given predicate or nil if no such element is found.

`func flatMap<SegmentOfResult>((Self.Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, SegmentOfResult>>`

Returns a cursor over the concatenated results of mapping transform over self.

`func flatMap<SegmentOfResult>((Self.Element) throws -> SegmentOfResult) -> FlattenCursor<MapCursor<Self, AnyCursor<SegmentOfResult.Element>>>`

Calls the given closure on each element in the cursor.

**Required** Default implementations provided.

Returns the elements of this cursor of cursors, concatenated.

`func joined() -> FlattenCursor<MapCursor<Self, AnyCursor<Self.Element.Element>>>`

Returns the elements of this cursor of sequences, concatenated.

Returns a cursor over the results of the transform function applied to this cursor’s elements.

Returns the maximum element in the cursor.

Returns the maximum element in the cursor, using the given predicate as the comparison between elements.

Returns the minimum element in the cursor.

Returns the minimum element in the cursor, using the given predicate as the comparison between elements.

Advances to the next element and returns it, or nil if no next element exists.

**Required** Default implementation provided.

Returns a cursor, up to the specified maximum length, containing the initial elements of the cursor.

Returns a cursor of the initial consecutive elements that satisfy `predicate`.

Returns the result of calling the given combining closure with each element of this cursor and an accumulating value.

Returns an array, up to the given maximum length, containing the final elements of the cursor.

## Relationships

### Inherited By

- `DatabaseCursor`

### Conforming Types

- `AnyCursor`
- `DatabaseValueCursor`
- `DropFirstCursor`
Conforms when `Base` conforms to `Cursor`.

- `DropWhileCursor`
Conforms when `Base` conforms to `Cursor`.

- `EnumeratedCursor`
Conforms when `Base` conforms to `Cursor`.

- `FastDatabaseValueCursor`
- `FilterCursor`
Conforms when `Base` conforms to `Cursor`.

- `FlattenCursor`
Conforms when `Base` conforms to `Cursor` and `Base.Element` conforms to `Cursor`.

- `MapCursor`
Conforms when `Base` conforms to `Cursor`, `Element` conforms to `Copyable`, and `Element` conforms to `Escapable`.

- `PrefixCursor`
Conforms when `Base` conforms to `Cursor`.

- `PrefixWhileCursor`
Conforms when `Base` conforms to `Cursor`.

- `RecordCursor`
- `RowCursor`
- `SQLStatementCursor`

## See Also

### Supporting Types

`protocol FetchRequest`

A type that fetches and decodes database rows.

- Cursor
- Overview
- Relationship with standard Sequence and IteratorProtocol
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fetchrequest

- GRDB
- SQL, Prepared Statements, Rows, and Values
- FetchRequest

Protocol

# FetchRequest

A type that fetches and decodes database rows.

FetchRequest.swift

## Overview

The main kinds of fetch requests are `SQLRequest` and `QueryInterfaceRequest`:

let lastName = "O'Reilly"

// SQLRequest

SELECT * FROM player WHERE lastName = \(lastName)
"""

// QueryInterfaceRequest
let request = Player.filter(Column("lastName") == lastName)

// Use the request
try dbQueue.read { db in
let players = try request.fetchAll(db) // [Player]
}

## Topics

### Counting the Results

Returns the number of rows fetched by the request.

**Required**

### Fetching Database Rows

Returns a cursor over fetched rows.

Returns an array of fetched rows.

Returns a single row.

Returns a set of fetched rows.

### Fetching Database Values

Returns a cursor over fetched values.

Returns an array of fetched values.

Returns a single fetched value.

Returns a set of fetched values.

### Fetching Records

Returns a cursor over fetched records.

Returns an array of fetched records.

Returns a single record.

Returns a set of fetched records.

### Preparing Database Requests

Returns a `PreparedRequest`.

`struct PreparedRequest`

A `PreparedRequest` is a request that is ready to be executed.

### Adapting the Fetched Rows

Returns an adapted request.

`struct AdaptedFetchRequest`

An adapted request.

### Supporting Types

`struct AnyFetchRequest`

A type-erased FetchRequest.

### Associated Types

`associatedtype RowDecoder`

The type that tells how fetched database rows should be interpreted.

## Relationships

### Inherits From

- `DatabaseRegionConvertible`
- `SQLExpressible`
- `SQLOrderingTerm`
- `SQLSelectable`
- `SQLSpecificExpressible`
- `SQLSubqueryable`
- `Swift.Sendable`

### Conforming Types

- `AdaptedFetchRequest`
Conforms when `Base` conforms to `FetchRequest`.

- `AnyFetchRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `QueryInterfaceRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

- `SQLRequest`
Conforms when `RowDecoder` conforms to `Copyable` and `Escapable`.

## See Also

### Supporting Types

`protocol Cursor`

A type that supplies the values of some external resource, one at a time.

- FetchRequest
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databaseconnections),

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/statement)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasecursor)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/row):

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sqlrequest)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/row)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasevalue)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/statement).

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/sql)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasequestionmarks(count:))

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasedatecomponents)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasevalueconvertible)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/statementcolumnconvertible)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/cursor)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/fetchrequest)

Has it really been five years since Swift Package Index launched? Read our anniversary blog post!

#### 404 - Not Found

If you were expecting to find a page here, please raise an issue.

From here, you'll want to go to the home page or search for a package.

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasesharing

- GRDB
- Concurrency
- Sharing a Database

Article

# Sharing a Database

How to share an SQLite database between multiple processes • Recommendations for App Group containers, App Extensions, App Sandbox, and file coordination.

## Overview

**This guide describes a recommended setup that applies as soon as several processes want to access the same SQLite database.** It complements the Concurrency guide, that you should read first.

On iOS for example, you can share database files between multiple processes by storing them in an App Group Container. On macOS, several processes may want to open the same database, according to their particular sandboxing contexts.

Accessing a shared database from several SQLite connections, from several processes, creates challenges at various levels:

1. **Database setup** may be attempted by multiple processes, concurrently, with possible conflicts.

2. **SQLite** may throw `SQLITE_BUSY` errors, “database is locked”.

3. **iOS** may kill your application with a `0xDEAD10CC` exception.

4. **GRDB** Database Observation does not detect changes performed by external processes.

We’ll address all of those challenges below.

## Use the WAL mode

In order to access a shared database, use a `DatabasePool`. It opens the database in the WAL mode, which helps sharing a database because it allows multiple processes to access the database concurrently.

It is also possible to use a `DatabaseQueue`, with the `.wal` `journalMode`.

Since several processes may open the database at the same time, protect the creation of the database connection with an NSFileCoordinator.

- In a process that can create and write in the database, use this sample code:

/// Returns an initialized database pool at the shared location databaseURL

let coordinator = NSFileCoordinator(filePresenter: nil)
var coordinatorError: NSError?
var dbPool: DatabasePool?
var dbError: Error?
coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError) { url in
do {
dbPool = try openDatabase(at: url)
} catch {
dbError = error
}
}
if let error = dbError ?? coordinatorError {
throw error
}
return dbPool!
}

var configuration = Configuration()
configuration.prepareDatabase { db in
// Activate the persistent WAL mode so that
// read-only processes can access the database.
//
// See
// and
if db.configuration.readonly == false {
var flag: CInt = 1
let code = withUnsafeMutablePointer(to: &flag) { flagP in
sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
}
guard code == SQLITE_OK else {
throw DatabaseError(resultCode: ResultCode(rawValue: code))
}
}
}
let dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)

// Perform here other database setups, such as defining
// the database schema with a DatabaseMigrator, and
// checking if the application can open the file:
try migrator.migrate(dbPool)
if try dbPool.read(migrator.hasBeenSuperseded) {
// Database is too recent
throw /* some error */
}

return dbPool
}

- In a process that only reads in the database, use this sample code:

/// Returns an initialized database pool at the shared location databaseURL,
/// or nil if the database is not created yet, or does not have the required
/// schema version.

let coordinator = NSFileCoordinator(filePresenter: nil)
var coordinatorError: NSError?
var dbPool: DatabasePool?
var dbError: Error?
coordinator.coordinate(readingItemAt: databaseURL, options: .withoutChanges, error: &coordinatorError) { url in
do {
dbPool = try openReadOnlyDatabase(at: url)
} catch {
dbError = error
}
}
if let error = dbError ?? coordinatorError {
throw error
}
return dbPool
}

do {
var configuration = Configuration()
configuration.readonly = true
let dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)

// Check here if the database schema is the expected one,
// for example with a DatabaseMigrator:
return try dbPool.read { db in
if try migrator.hasBeenSuperseded(db) {
// Database is too recent
return nil
} else if try migrator.hasCompletedMigrations(db) == false {
// Database is too old
return nil
}
return dbPool
}
} catch {
if FileManager.default.fileExists(atPath: databaseURL.path) {
throw error
} else {
return nil
}
}
}

#### The Specific Case of Read-Only Connections

Read-only connections will fail unless two extra files ending in `-shm` and `-wal` are present next to the database file ( source). Those files are regular companions of databases in the WAL mode. But they are deleted, under regular operations, when database connections are closed. Precisely speaking, they _may_ be deleted: it depends on the SQLite and the operating system versions ( source). And when they are deleted, read-only connections fail.

The solution is to enable the “persistent WAL mode”, as shown in the sample code above, by setting the SQLITE\_FCNTL\_PERSIST\_WAL flag. This mode makes sure the `-shm` and `-wal` files are never deleted, and guarantees a database access to read-only connections.

## How to limit the SQLITE\_BUSY error

If several processes want to write in the database, configure the database pool of each process that wants to write:

var configuration = Configuration()
configuration.busyMode = .timeout(/* a TimeInterval */)
let dbPool = try DatabasePool(path: ..., configuration: configuration)

The busy timeout has write transactions wait, instead of throwing `SQLITE_BUSY`, whenever another process is writing. GRDB automatically opens all write transactions with the IMMEDIATE kind, preventing write transactions from overlapping.

With such a setup, you will still get `SQLITE_BUSY` errors if the database remains locked by another process for longer than the specified timeout. You can catch those errors:

do {
try dbPool.write { db in ... }
} catch DatabaseError.SQLITE_BUSY {
// Another process won't let you write. Deal with it.
}

## How to limit the 0xDEAD10CC exception

#### If you use SQLCipher

Use SQLCipher 4+, and configure the database from `prepareDatabase(_:)`:

var configuration = Configuration()
configuration.prepareDatabase { (db: Database) in
try db.usePassphrase("secret")
try db.execute(sql: "PRAGMA cipher_plaintext_header_size = 32")
}
let dbPool = try DatabasePool(path: ..., configuration: configuration)

Applications become responsible for managing the salt themselves: see instructions. See also for more context and information.

#### In all cases

The technique described below is based on this discussion on the Apple Developer Forums. It is **🔥 EXPERIMENTAL**.

In each process that writes in the database, set the `observesSuspensionNotifications` configuration flag:

var configuration = Configuration()
configuration.observesSuspensionNotifications = true
let dbPool = try DatabasePool(path: ..., configuration: configuration)

Post `suspendNotification` when the application is about to be suspended. You can for example post this notification from `UIApplicationDelegate.applicationDidEnterBackground(_:)`, or in the expiration handler of a background task:

class AppDelegate: UIResponder, UIApplicationDelegate {
func applicationDidEnterBackground(_ application: UIApplication) {
NotificationCenter.default.post(name: Database.suspendNotification, object: self)
}
}

Once suspended, a database won’t acquire any new lock that could cause the `0xDEAD10CC` exception.

In exchange, you will get `SQLITE_INTERRUPT` (code 9) or `SQLITE_ABORT` (code 4) errors, with messages “Database is suspended”, “Transaction was aborted”, or “interrupted”. You can catch those errors:

do {
try dbPool.write { db in ... }
} catch DatabaseError.SQLITE_INTERRUPT, DatabaseError.SQLITE_ABORT {
// Oops, the database is suspended.
// Maybe try again after database is resumed?
}

Post `resumeNotification` in order to resume suspended databases. You can safely post this notification when the app comes

Database Observation features are not able to detect database changes performed by other processes.

Whenever you need to notify other processes that the database has been changed, you will have to use a cross-process notification mechanism such as NSFileCoordinator or CFNotificationCenterGetDarwinNotifyCenter. You can trigger those notifications automatically with `DatabaseRegionObservation`:

// Notify all changes made to the database
let observation = DatabaseRegionObservation(tracking: .fullDatabase)
let observer = try observation.start(in: dbPool) { db in
// Notify other processes
}

// Notify changes made to the "player" and "team" tables only
let observation = DatabaseRegionObservation(tracking: Player.all(), Team.all())
let observer = try observation.start(in: dbPool) { db in
// Notify other processes
}

The processes that observe the database can catch those notifications, and deal with the notified changes. See Dealing with Undetected Changes for some related techniques.

## See Also

### Going Further

Swift Concurrency and GRDB

How to best integrate GRDB and Swift Concurrency

- Sharing a Database
- Overview
- Use the WAL mode
- How to limit the SQLITE\_BUSY error
- How to limit the 0xDEAD10CC exception
- How to perform cross-process database observation
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/read(_:)-3806d

-3806d#app-main)

- GRDB
- Concurrency
- DatabaseReader
- read(\_:)

Instance Method

# read(\_:)

Executes read-only database operations, and returns their result after they have finished executing.

DatabaseReader.swift

**Required**

## Parameters

`value`

A closure which accesses the database.

## Discussion

For example:

let count = try reader.read { db in
try Player.fetchCount(db)
}

Database operations are isolated in a transaction: they do not see changes performed by eventual concurrent writes (even writes performed by other processes).

The database connection is read-only: attempts to write throw a `DatabaseError` with resultCode `SQLITE_READONLY`.

The `Database` argument to `value` is valid only during the execution of the closure. Do not store or return the database connection for later use.

It is a programmer error to call this method from another database access method. Doing so raises a “Database methods are not reentrant” fatal error at runtime.

## See Also

### Reading from the Database

Returns a publisher that publishes one value and completes.

Schedules read-only database operations for execution, and returns immediately.

- read(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasewriter/write(_:)-76inz

-76inz#app-main)

- GRDB
- Concurrency
- DatabaseWriter
- write(\_:)

Instance Method

# write(\_:)

Executes database operations, and returns their result after they have finished executing.

DatabaseWriter.swift

## Parameters

`updates`

A closure which accesses the database.

## Discussion

For example:

let newPlayerCount = try writer.write { db in
try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

Database operations are wrapped in a transaction. If they throw an error, the transaction is rollbacked and the error is rethrown.

Concurrent database accesses can not see partial database updates (even when performed by other processes).

Database operations run in the writer dispatch queue, serialized with all database updates performed by this `DatabaseWriter`.

The `Database` argument to `updates` is valid only during the execution of the closure. Do not store or return the database connection for later use.

It is a programmer error to call this method from another database access method. Doing so raises a “Database methods are not reentrant” fatal error at runtime.

## See Also

### Writing into the Database

Returns a publisher that publishes one value and completes.

**Required**

Schedules database operations for execution, and returns immediately.

- write(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/read(_:)-5mfwu

-5mfwu#app-main)

- GRDB
- Concurrency
- DatabaseReader
- read(\_:)

Instance Method

# read(\_:)

Executes read-only database operations, and returns their result after they have finished executing.

DatabaseReader.swift

**Required**

## Parameters

`value`

A closure which accesses the database.

## Discussion

For example:

let count = try await reader.read { db in
try Player.fetchCount(db)
}

Database operations are isolated in a transaction: they do not see changes performed by eventual concurrent writes (even writes performed by other processes).

The database connection is read-only: attempts to write throw a `DatabaseError` with resultCode `SQLITE_READONLY`.

The `Database` argument to `value` is valid only during the execution of the closure. Do not store or return the database connection for later use.

## See Also

### Reading from the Database

Returns a publisher that publishes one value and completes.

Schedules read-only database operations for execution, and returns immediately.

- read(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasewriter/write(_:)-4gnqx

-4gnqx#app-main)

- GRDB
- Concurrency
- DatabaseWriter
- write(\_:)

Instance Method

# write(\_:)

Executes database operations, and returns their result after they have finished executing.

DatabaseWriter.swift

## Parameters

`updates`

A closure which accesses the database.

## Discussion

For example:

let newPlayerCount = try await writer.write { db in
try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

Database operations are wrapped in a transaction. If they throw an error, the transaction is rollbacked and the error is rethrown.

Concurrent database accesses can not see partial database updates (even when performed by other processes).

Database operations run in the writer dispatch queue, serialized with all database updates performed by this `DatabaseWriter`.

The `Database` argument to `updates` is valid only during the execution of the closure. Do not store or return the database connection for later use.

## See Also

### Writing into the Database

Returns a publisher that publishes one value and completes.

**Required**

Schedules database operations for execution, and returns immediately.

- write(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/swiftconcurrency

- GRDB
- Concurrency
- Swift Concurrency and GRDB

Article

# Swift Concurrency and GRDB

How to best integrate GRDB and Swift Concurrency

## Overview

GRDB’s primary goal is to leverage SQLite’s concurrency features for the benefit of application developers. Swift 6 makes it possible to achieve this goal while ensuring data-race safety.

For example, the `DatabasePool` connection allows applications to fetch and display database values on screen, even while a background task is writing the results of a network request to disk.

Application previews and tests prefer to use an in-memory `DatabaseQueue` connection.

Both connection types provide the same database access methods:

// Read
let playerCount = try await writer.read { db in
try Player.fetchCount(db)
}

// Write
let newPlayerCount = try await writer.write { db in
try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

// Observe database changes
let observation = ValueObservation.tracking { db in
try Player.fetchAll(db)
}
for try await players in observation.values(in: writer) {
print("Fresh players", players)
}

`DatabaseQueue` serializes all database accesses, when `DatabasePool` allows parallel reads and writes. The common `DatabaseWriter` protocol provides the SQLite isolation guarantees that abstract away the differences between the two connection types, without sacrificing data integrity. See the Concurrency guide for more information.

All safety guarantees of Swift 6 are enforced during database accesses. They are controlled by the language mode and level of concurrency checkings used by your application, as described in Migrating to Swift 6 on swift.org.

The following sections describe, with more details, how GRDB interacts with Swift Concurrency.

- Shorthand Closure Notation

- Non-Sendable Configuration of Record Types

- Non-Sendable Record Types

- Choosing between Synchronous and Asynchronous Database Accesses

### Shorthand Closure Notation

In the Swift 5 language mode, the compiler emits a warning when a database access is written with the shorthand closure notation:

// Standard closure:
let count = try await writer.read { db in
try Player.fetchCount(db)
}

// Shorthand notation:
// ⚠️ Converting non-sendable function value to '@Sendable (Database)

let count = try await writer.read(Player.fetchCount)

**You can remove this warning** by enabling SE-0418: Inferring `Sendable` for methods and key path literals, as below:

- **Using Xcode**

Set `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` to `YES` in the build settings of your target.

- **In a SwiftPM package manifest**

Enable the `InferSendableFromCaptures` upcoming feature:

.target(
name: "MyTarget",
swiftSettings: [\
.enableUpcomingFeature("InferSendableFromCaptures")\
]
)

This language feature is not enabled by default, because it can potentially affect source compatibility.

### Non-Sendable Configuration of Record Types

In the Swift 6 language mode, and in the Swift 5 language mode with strict concurrency checkings, the compiler emits an error or a warning when a record type specifies which columns it fetches from the database, with the `databaseSelection` static property:

extension Player: FetchableRecord, PersistableRecord {
// ❌ Static property 'databaseSelection' is not concurrency-safe
// because non-'Sendable' type '[any SQLSelectable]'
// may have shared mutable state
static let databaseSelection: [any SQLSelectable] = [\
Columns.id, Columns.name, Columns.score\
]

enum Columns {
static let id = Column("id")
static let name = Column("name")
static let score = Column("score")
}
}

**To fix this error**, replace the stored property with a computed property:

extension Player: FetchableRecord, PersistableRecord {
static var databaseSelection: [any SQLSelectable] {
[Columns.id, Columns.name, Columns.score]
}
}

### Non-Sendable Record Types

In the Swift 6 language mode, and in the Swift 5 language mode with strict concurrency checkings, the compiler emits an error or a warning when the application reads, writes, or observes a non- `Sendable` type.

By default, Swift classes are not Sendable. They are not thread-safe. With GRDB, record classes will typically trigger compiler diagnostics:

// A non-Sendable record type
final class Player: Codable, Identifiable {
var id: Int64
var name: String
var score: Int
}

extension Player: FetchableRecord, PersistableRecord { }

// ❌ Type 'Player' does not conform to the 'Sendable' protocol
let player = try await writer.read { db in
try Player.fetchOne(db, id: 42)
}

// ❌ Capture of 'player' with non-sendable type 'Player' in a `@Sendable` closure
let player: Player
try await writer.read { db in
try player.insert(db)
}

// ❌ Type 'Player' does not conform to the 'Sendable' protocol
let observation = ValueObservation.tracking { db in
try Player.fetchAll(db)
}

#### The solution

The solution is to have the record type conform to `Sendable`.

Since classes are difficult to make `Sendable`, the easiest way to is to replace classes with structs composed of `Sendable` properties:

// This struct is Sendable
struct Player: Codable, Identifiable {
var id: Int64
var name: String
var score: Int
}

You do not need to perform this refactoring right away: you can compile your application in the Swift 5 language mode, with minimal concurrency checkings. Take your time, and only when your application is ready, enable strict concurrency checkings or the Swift 6 language mode.

#### FAQ: My application defines record classes, because…

- **Question: My record types are subclasses of the built-in GRDB `Record` class.**

Consider refactoring them as structs. The `Record` class was present in GRDB 1.0, in 2017. It has served its purpose. It is not `Sendable`, and its use is actively discouraged since GRDB 7.

- **Question: I need a hierarchy of record classes because I use inheritance.**

It should be possible to refactor the class hiearchy with Swift protocols. See Record Timestamps and Transaction Date for a practical example. Protocols make it possible to define records as structs.

- **Question: I use the `@Observable` macro for my record types, and this macro requires a class.**

A possible solution is to define two types: an `@Observable` class that drives your SwiftUI views, and a plain record struct for database work. An indirect advantage is that you will be able to make them evolve independently.

- **Question: I use classes instead of structs because I monitored my application and classes have a lower CPU/memory footprint.**

Now that’s tricky. Please do not think the `Sendable` requirement is a whim: see the following questions.

#### FAQ: How to make classes Sendable?

- **Question: Can I mark my record classes as `@unchecked Sendable`?**

Take care that all humans and machines who will read your code will think that the class is thread-safe, so make sure it really is. See the following questions.

- **Question: I can use locks to make my class safely Sendable.**

You can indeed put a lock on the whole instance, or on each individual property, or on multiple subgroups of properties, as needed by your application. Remember that structs are simpler, because they do not need locks and the compiler does all the hard work for you.

- **Question: Can I make my record classes immutable?**

Yes. Classes that can not be modified, made of constant `let` properties, are Sendable. Those immutable classes will not make it easy to modify the database, though.

### Choosing between Synchronous and Asynchronous Database Accesses

GRDB connections provide two versions of `read` and `write`, one that is synchronous, and one that is asynchronous. It might not be clear how to choose one or the other.

// Synchronous database access
try writer.write { ... }

// Asynchronous database access
await try writer.write { ... }

Synchronous database accesses are handy. They avoid undesired delays, flashes of missing content in the user interface, or `async` functions. Many apps access the database synchronously, even from the main thread, because SQLite is very fast. Of course, it is still possible to run slow queries: in this case, asynchronous accesses should be preferred. They are guaranteed to never block the main thread.

Performing synchronous accesses from Swift Concurrency tasks is not incorrect.

Some people recommend to avoid performing long blocking jobs on the cooperative thread pool, so you might want to follow this advice, and prefer to always `await` for the database in Swift tasks. In many occasions, the compiler will help you. For example, in the sample code below, the compiler requires the `await` keyword:

try await writer.read(Player.fetchAll)
}

But there are some scenarios where the compiler misses opportunities to use `await`, such as inside closures ( swiftlang/swift#74459):

Task {
// The compiler does not spot the missing `await`
let players = try writer.read(Player.fetchAll)
}

## See Also

### Going Further

Sharing a Database

How to share an SQLite database between multiple processes • Recommendations for App Group containers, App Extensions, App Sandbox, and file coordination.

- Swift Concurrency and GRDB
- Overview
- Shorthand Closure Notation
- Non-Sendable Configuration of Record Types
- Non-Sendable Record Types
- Choosing between Synchronous and Asynchronous Database Accesses
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/readpublisher(receiveon:value:)

#app-main)

- GRDB
- Concurrency
- DatabaseReader
- readPublisher(receiveOn:value:)

Instance Method

# readPublisher(receiveOn:value:)

Returns a publisher that publishes one value and completes.

receiveOn scheduler: some Scheduler = DispatchQueue.main,

DatabaseReader.swift

## Parameters

`scheduler`

A Combine Scheduler.

`value`

A closure which accesses the database.

## Discussion

The database is not accessed until subscription. Value and completion are published on `scheduler` (the main dispatch queue by default).

For example:

try Player.fetchCount(db)
}

Database operations are isolated in a transaction: they do not see changes performed by eventual concurrent writes (even writes performed by other processes).

The database connection is read-only: attempts to write throw a `DatabaseError` with resultCode `SQLITE_READONLY`.

The `Database` argument to `value` is valid only during the execution of the closure. Do not store or return the database connection for later use.

## See Also

### Reading from the Database

Executes read-only database operations, and returns their result after they have finished executing.

**Required**

Schedules read-only database operations for execution, and returns immediately.

- readPublisher(receiveOn:value:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasewriter/writepublisher(receiveon:updates:)

#app-main)

- GRDB
- Concurrency
- DatabaseWriter
- writePublisher(receiveOn:updates:)

Instance Method

# writePublisher(receiveOn:updates:)

Returns a publisher that publishes one value and completes.

receiveOn scheduler: some Scheduler = DispatchQueue.main,

DatabaseWriter.swift

## Parameters

`scheduler`

A Combine Scheduler.

`updates`

A closure which accesses the database.

## Discussion

The database is not accessed until subscription. Value and completion are published on `scheduler` (the main dispatch queue by default).

For example:

try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

Database operations are wrapped in a transaction. If they throw an error, the transaction is rollbacked and the error completes the publisher.

Concurrent database accesses can not see partial database updates (even when performed by other processes).

Database operations are asynchronously dispatched in the writer dispatch queue, serialized with all database updates performed by this `DatabaseWriter`.

The `Database` argument to `updates` is valid only during the execution of the closure. Do not store or return the database connection for later use.

## See Also

### Writing into the Database

Executes database operations, and returns their result after they have finished executing.

**Required**

Schedules database operations for execution, and returns immediately.

- writePublisher(receiveOn:updates:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/asyncread(_:)

#app-main)

- GRDB
- Concurrency
- DatabaseReader
- asyncRead(\_:)

Instance Method

# asyncRead(\_:)

Schedules read-only database operations for execution, and returns immediately.

DatabaseReader.swift

**Required**

## Parameters

`value`

A closure which accesses the database. Its argument is a `Result` that provides the database connection, or the failure that would prevent establishing the read access to the database.

## Discussion

For example:

try reader.asyncRead { dbResult in
do {
let db = try dbResult.get()
let count = try Player.fetchCount(db)
} catch {
// Handle error
}
}

Database operations are isolated in a transaction: they do not see changes performed by eventual concurrent writes (even writes performed by other processes).

The database connection is read-only: attempts to write throw a `DatabaseError` with resultCode `SQLITE_READONLY`.

## See Also

### Reading from the Database

Executes read-only database operations, and returns their result after they have finished executing.

Returns a publisher that publishes one value and completes.

- asyncRead(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasewriter/asyncwrite(_:completion:)

#app-main)

- GRDB
- Concurrency
- DatabaseWriter
- asyncWrite(\_:completion:)

Instance Method

# asyncWrite(\_:completion:)

Schedules database operations for execution, and returns immediately.

)

DatabaseWriter.swift

## Parameters

`updates`

A closure which accesses the database.

`completion`

A closure called with the transaction result.

## Discussion

For example:

try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
} completion: { db, result in
switch result {
case let .success(newPlayerCount):
// Handle success
case let .failure(error):
// Handle error
}

Database operations run by the `updates` closure are wrapped in a transaction. If they throw an error, the transaction is rollbacked.

The `completion` closure has two arguments: a database connection, and the result of the transaction. This result is a failure if the transaction could not be committed or if `updates` has thrown an error.

Concurrent database accesses can not see partial database updates performed by `updates` (even when performed by other processes).

Database operations run in the writer dispatch queue, serialized with all database updates performed by this `DatabaseWriter`.

The `Database` argument to `updates` and `completion` is valid only during the execution of those closures. Do not store or return the database connection for later use.

## See Also

### Writing into the Database

Executes database operations, and returns their result after they have finished executing.

Returns a publisher that publishes one value and completes.

**Required**

- asyncWrite(\_:completion:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasewriter

- GRDB
- Concurrency
- DatabaseWriter

Protocol

# DatabaseWriter

A type that writes into an SQLite database.

protocol DatabaseWriter : DatabaseReader

DatabaseWriter.swift

## Overview

Do not declare new conformances to `DatabaseWriter`. Only the built-in conforming types are valid.

A database writer creates one single SQLite connection dedicated to database updates. All updates are executed in a serial **writer dispatch queue**.

Read accesses are defined by `DatabaseReader`, the protocol all database writers conform to.

See Concurrency for more information about the behavior of conforming types in a multithreaded application.

## Topics

### Writing into the Database

Executes database operations, and returns their result after they have finished executing.

Returns a publisher that publishes one value and completes.

**Required**

Schedules database operations for execution, and returns immediately.

### Exclusive Access to the Database

### Reading from the Latest Committed Database State

Schedules read-only database operations for execution.

### Unsafe Methods

### Observing Database Transactions

`func add(transactionObserver: some TransactionObserver, extent: Database.TransactionObservationExtent)`

Adds a transaction observer to the writer connection, so that it gets notified of database changes and transactions.

`func remove(transactionObserver: some TransactionObserver)`

Removes a transaction observer from the writer connection.

### Other Database Operations

`func erase() throws`

Erase the database: delete all content, drop all tables, etc.

`func erase() async throws`

`func vacuum() throws`

Rebuilds the database file, repacking it into a minimal amount of disk space.

`func vacuum() async throws`

`func vacuum(into: String) throws`

Creates a new database file at the specified path with a minimum amount of disk space.

`func vacuum(into: String) async throws`

### Supporting Types

`class AnyDatabaseWriter`

A type-erased database writer.

## Relationships

### Inherits From

- `DatabaseReader`
- `Swift.Sendable`

### Conforming Types

- `AnyDatabaseWriter`
- `DatabasePool`
- `DatabaseQueue`

## See Also

### Database Connections with Concurrency Guarantees

`protocol DatabaseReader`

A type that reads from an SQLite database.

`protocol DatabaseSnapshotReader`

A type that sees an unchanging database content.

- DatabaseWriter
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasewriter/unsafereentrantwrite(_:)

#app-main)

- GRDB
- Concurrency
- DatabaseWriter
- unsafeReentrantWrite(\_:)

Instance Method

# unsafeReentrantWrite(\_:)

Executes database operations, and returns their result after they have finished executing.

DatabaseWriter.swift

**Required**

## Parameters

`updates`

A closure which accesses the database.

## Discussion

This method can be called from other database access methods. Reentrant database accesses are discouraged because they muddle transaction boundaries. See Rule 2: Mind your transactions for more information.

For example:

let newPlayerCount = try writer.unsafeReentrantWrite { db in
try Player(name: "Arthur").insert(db)
return try Player.fetchCount(db)
}

Database operations run in the writer dispatch queue, serialized with all database updates performed by this `DatabaseWriter`.

The `Database` argument to `updates` is valid only during the execution of the closure. Do not store or return the database connection for later use.

- unsafeReentrantWrite(\_:)
- Parameters
- Discussion

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader

- GRDB
- Concurrency
- DatabaseReader

Protocol

# DatabaseReader

A type that reads from an SQLite database.

protocol DatabaseReader : AnyObject, Sendable

DatabaseReader.swift

## Overview

Do not declare new conformances to `DatabaseReader`. Only the built-in conforming types are valid.

The protocol comes with isolation guarantees that describe the behavior of conforming types in a multithreaded application. See Concurrency for more information.

## Topics

### Database Information

`var configuration: Configuration`

The database configuration.

**Required**

`var path: String`

The path to the database file.

### Reading from the Database

Executes read-only database operations, and returns their result after they have finished executing.

Returns a publisher that publishes one value and completes.

Schedules read-only database operations for execution, and returns immediately.

### Unsafe Methods

Executes database operations, and returns their result after they have finished executing.

**Required** Default implementation provided.

Schedules database operations for execution, and returns immediately.

### Printing Database Content

`func dumpContent(format: some DumpFormat, to: (any TextOutputStream)?) throws`

Prints the contents of the database.

`func dumpRequest(some FetchRequest, format: some DumpFormat, to: (any TextOutputStream)?) throws`

Prints the results of a request.

`func dumpSchema(to: (any TextOutputStream)?) throws`

Prints the schema of the database.

`func dumpSQL(SQL, format: some DumpFormat, to: (any TextOutputStream)?) throws`

Prints the results of all statements in the provided SQL.

[`func dumpTables([String], format: some DumpFormat, tableHeader: DumpTableHeaderOptions, stableOrder: Bool, to: (any TextOutputStream)?) throws`](https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/dumptables(_:format:tableheader:stableorder:to:))

Prints the contents of the provided tables and views.

`protocol DumpFormat`

A type that prints database rows.

`enum DumpTableHeaderOptions`

Options for printing table names.

### Other Database Operations

Copies the database contents into another database.

`func close() throws`

Closes the database connection.

`func interrupt()`

Causes any pending database operation to abort and return at its earliest opportunity.

### Supporting Types

`class AnyDatabaseReader`

A type-erased database reader.

## Relationships

### Inherits From

- `Swift.Sendable`

### Inherited By

- `DatabaseSnapshotReader`
- `DatabaseWriter`

### Conforming Types

- `AnyDatabaseReader`
- `AnyDatabaseWriter`
- `DatabasePool`
- `DatabaseQueue`
- `DatabaseSnapshot`
- `DatabaseSnapshotPool`

## See Also

### Database Connections with Concurrency Guarantees

`protocol DatabaseWriter`

A type that writes into an SQLite database.

`protocol DatabaseSnapshotReader`

A type that sees an unchanging database content.

- DatabaseReader
- Overview
- Topics
- Relationships
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/documentation/grdb/databasereader/unsafereentrantread(_:)

#app-main)

- GRDB
- Concurrency
- DatabaseReader
- unsafeReentrantRead(\_:)

Instance Method

# unsafeReentrantRead(\_:)

Executes database operations, and returns their result after they have finished executing.

DatabaseReader.swift

**Required**

## Parameters

`value`

A closure which accesses the database.

## Discussion

This method is “unsafe” because the database reader does nothing more than providing a database connection. When you use this method, you become responsible for the thread-safety of your application, and responsible for database accesses performed by other processes. See Safe and Unsafe Database Accesses for more information.

This method can be called from other database access methods. If called from the dispatch queue of a current database access (read or write), the `Database` argument to `value` is the same as the current database access.

Reentrant database accesses are discouraged because they muddle transaction boundaries (see Rule 2: Mind your transactions for more information).

For example:

let count = try reader.unsafeReentrantRead { db in
try Player.fetchCount(db)
}

The `Database` argument to `value` is valid only during the execution of the closure. Do not store or return the database connection for later use.

## See Also

### Unsafe Methods

**Required** Default implementation provided.

Schedules database operations for execution, and returns immediately.

- unsafeReentrantRead(\_:)
- Parameters
- Discussion
- See Also

|
|

---

# https://swiftpackageindex.com/groue/grdb.swift/v7.6.1/images/GRDB/DatabaseQueueScheduling.png

�PNG


IHDR�.q�@�sRGB���DeXIfMM\*�i���.�#��@IDATx�\`E���@���!t���Q�7QDD@�S��(�P��Ċ��

b�^� -�H/�͛�w�\\�R.w���
l������۷3;�\[\
%ԭ\_��RB�.�B@!Ph����+h߾}1�.M�#�\
6�U�V��k�O�D\`�֭�sU1���f�\\Uڏ�OvM! ����B@& ܟ�+�&��~K@�ߪVvL! ���p֮�B@�-1�~�Z�1! ���gb��Y��oB@!�Ā��jeǄ�B�� x�S��Q\[)U������������E�t��~��W8p \[�DJ&:��/\_^�������o�� 1111�2R�� ��s���?/��ˀ\_����l�\*�^j�Dm��&.�.\]��\
���\
;�ƠA�������W��{��W\_}岁cǎ�n��r����$û�-\[��M���6n܈#G��ꫯ.�c��:}�t�@�����?�A�J�P�^=���.�J�w L�4��y��K/Ս��s��u�r��!&&��vRRR��˵��\*�\_U��l}h��w�v�����ޠ�Zj;�6q� йsg�����ۇq��aŊ�i�7�ѣ����7����ߏ^�z��(��\
/@�\\r�% }�ۿ?&L�2�\|L5j�t���nݺu�:u\*�z�-������1f�T�R�^{��w���w��������E:�믿��3��xHHH���ݻw���x�лwo������ֿ������cG���T?�62��~V�ūp��Q��T��ԿU�9��Om4;@m4Dۡ��jcGS�3ԶSm4�Vmy\]X�"%�U�ZU\_ �� �#�K�.����H������ر#���0b���M�вeK=:��\]����1z�hT�V\
T�G}d��4�ڮ\];�/\_:t�ʕ+��iii��Y�N�i�\_~��=�Y�СC�駟��O8˖�"$@��e�\]�7�/92��fS�C@����ի�3S�7o�z�\[7-Z��'7��.&o��FԮ\]ݻwǒ%K(������/F�ʕѩS'\|�-�����ŋu{u��Ŵi�r�§���^{M�d���УG�?�H�qEM��:O�F�V�1���t�����E�H-�~��eժU�n5�������QW庯�N�r�\*qq:��m����B�����l��m�6�ާO��p����{e�-jī��qB�TϞ=-���B��,�8\[����ڵk-���������e��ݫ��9s�X�z ��墏�'N�\|u����"Ϣ.�,S�L�m��l}s��ܹs��5kZ�}��\|�wUOq��˹JTˀr���q�R#e}���I�?�\`Qr����v�\\E��B�Y�mL}^�WZ�t\\�j$2b��2d\_T�F��\

\
6��pmhDOo�su��}ݧsUq�7ѽ�\|oSH�� ��CK�hn.O���<+��St1(ǕI��v\\�bIgr���1E3E��\|a\
�\_X�~! ��(2b���4$��B�sĀ{���$��B���/2�ҐB@��9�R�B@�"# ��PKCB@! Bo1�j���D���bc7�e˖ztN��p�'℀$k�����dlڴ ��k�q���80�Q�iTͰyиJy����C����Ͼ�ظq#ڶm���P�\]��y�IX�@!�ρ������i�U���VGc�7�\|�p�9L��<�4N'���o�9�1���'g�a�sL�t�ə�f���8�\|rf��<�4N'���o�)�tC:"\]��X�'N!HrΣjӧ{ޥ�C�����B�1��ɘP�\|G�B

�T9���T��f5F&٧,���9ξ���Ͼ�\[ 0��ïrT���^��}5:�\_!��nN\

�\|p�}N����c���\|�����t�'��3/��&���9�'��?���R���΢8���2g��?��2�ƾ�GaN���c��! �@�����#6�A5�p���q�)��V�,kʘ���W��V�����\_��MG��$�Opg+W��}I�����P\|! ��?�8oR,��n�F�D�M�\[����{�ĉ'\
\\WAڞ~�=���K.��f���ܡ5jU��ZU\*�\_�˰m�V{����\\���������LJJj�e\\�y��QԯUё������.9M\|! ��?Xn��9�G�J���yl�i�SޱcGQ�ti����z�;\` V}�\

z�����ؓ���a�Y�J�gffb�SO�Kڢ�E\
p���� �y\\\]�x�uhR�Z6���N�Ą���i�{���5D?e�׭���uj��\*��}��rٲe1m������7����-Vr���o��~=uԯKڶ@��c�z����Msԯ�+��¶m4j��Y���g��2�{vŴ{��ۣ���/G�:�p��p���~Q����/^�I��}j�/�@�;�1�r˳�B@��# ܦseg��)�Ƈ�)G�e%W�FM\]���<�AW
��S��w+�����ԧ03u������q�ㆱ7��%�������G���� �{
�;f�:�o��闛���j�\|T�9�zo\|��hҴ�w����ݷ�ĩS'�2��?��i

7ѷ���oXwR�! ��p��i�H9�o��
kY5�Q8M���k���\_\_�K�x�ЩMSu�{ ���l͔����;��;���M���j��Ԅ����ڶ兀�-7j8�������6�L��.������}�\]�o�/����n��̥������3�0x@�٬g��~����'���cn���?��vǕj��·������63���wޘ���V%7r􍘬���!����\_���x\\1xH�<�t�5��U8�fș�,�i��Z@�! ��7?��C������~�zK���T5?���1V�hQmk֬A���)�UX����˳gN�ѯ�X���L#��

9���

O@x�Ǜ ��F�4�����y�fԊ�F����df��H��P�Hn��b������}��H��bċG7�j�Ā��HJ�\`�M��4�Y'J寧z��8\_#@�!���Ȉ��؈�Z�?B����@x�r�O�)j�ƛ�=ԜT�ad�ϝ��3�oҙ�{�I�N����V��¥�ϾJ�e�%Cx�����ӕ18�&M��q7M�\[7�O�2fYW2f��gg�?��t'\\�1H5^# #p���������FEV\

8�ղ��8�P�EL�G��=�d\]TVĝ���&@:#ݱ�\`��R�L@��K��E�O����y��?�}1�%S���k1���aٿ"!�'z�1kZa�����y��a�w���tCnR�pq^�����=ܲb�J\[�����\]�&zv�}���zO���5W߀o���vܑq��c�U{�����G�a����5��s�ZQ���p�9����?B����)uHg��������}8��=�G�{��x������\_~��7P�~S�궭�j�߷�Uhָ�.7f�D���\|��u �lކ
�7�+�Y�ө����@ú�ѭ��6/k����oV�Bٲe0��ѻOw��/�\|�e��h�R�E��\_﫵

�?�؀��u�����{w��q����\`���b���X�.2��
�}P�~jש��7������R�����.

�=���~ӦOU�V��o��\_���ؼc���u�=d7n�ǎ���yoc���˕������S�\`�\|��r���a���tY�{

�)-��-��5l\]�f��F����\_Z,׸i�<���o�g��(�}v3MWb�q���\*U�t���\*$(����Q��h��Z@V<�K�B@�+1���Y�/� @��℀� �T�N!\`#��R ! ��� ��4Q�/� ���mi�c�a�;\[By�ξI��D�J��e�g�7ݱL�r��B���-H����˪������wxӋXl�\
1���t�9�\|3�;+�,�L3�"�E��(?E�tG�u�UPBB�w��\]HO�������q�\\�zS�7f~�Gv�tF���#\
�n�$��3\]�:��r���D \*\*\
�q�\]��Y.��8��\*QuJJw��L@x+\_v�sx�f�:'�w����4��gqJ�-�\

ӛ�bbbP�F\
����� uo�@�zqH�zc\[:���E��\*\]PEG�AS�ڜ�9n��E�}/vO�"�M^��Ha!�O�d��\

}K/���x�D��C6�\

!��xӴ9���լ��wE�N����\

P�/��6��F��Q�tim�\[4�E,Q��w)��={\]��-�j�ʕ+b̨I�k�n�oP�����Ƌ/?���\_�\];Q��r��\[�θn�P\|��3\|�l%��\*k�}���h��"���jy�0�\|�)\\��bU�\

�}��
Zs˄#Dm��2��\[���3�r��(My�Q�����),SM���Qc�c�+O��O�,ú����3մzc��a�f���U�O�<�C��C�6\*�����9!e�b���<��s�zaݩ�8-Cr����t;~����f~\]�R=7���$�}�5�C5P;Y2,�۾q���8�5�q��i=ː��do���%}���7�J�B@/�N

q�����\|��wK?\_���������AA��q�V���7~�u��5W��#2�bkǙL^������۠����\\��c�������tr����I'#pOҔ���EB��z�4�͜���1��w��#��5�\`ص�p\\=�<�Յx��9���?S�\[���\`��{й�ԉ��\[n���.X��7��o��6������U�p�5g���x�\|:\]0<�ċ�O\*D���f�F���Ҹ�����Ӏ��q��?�e�X���w\\w�5�P3�W-��doǙL^��w�g��Q:5<"-\[6�;￤V�w���D���׹z�Y� S�C����\[�~��}��ިZ�\`6l@�V���캧 lݺ��-�m͚5���:\]�龚���we�Z���\]\\��W��7�.$�i�P���Q�Y<##{�P�8u��vVD��(�^�ʎ�G���j#�i�����o��������Cs�U���� �\
����HD2e�r˛�녔B@�Z�mWE=cM�Y\[��\*�̣��r4�W�,�IDATvs.�3��V���M�Tg�q��2���}�w��3Ӹ,��2��۾�\\I�ŀ�-I���d-�ʖ,��" <��-;+��?��uqB@�B@�F�{\*aݖ�z��p�ꄀ�&\`}�Z+}/;==C-.SO�@��j#ʣt��Nq��\[����L��sV��SN+�/��Ĥ�B�� ��z�IZJ�z��LV/�g�XC�ξ�o��age��ifX�0�\*���ȱ.�\
��7�B@9:񇇇������\|���;$\
��t�)�M\
��7~)(��(~QQQ8y� ��Z�\*�I�C�l\\�F��O�\|��oTRP!P�x�f�:����޽{��������\
�o���"���\`S�2q�\\�\_���f8�/��H�wPx�QIA! �@��=�eʔQ�٬�����Q�U��+�!���9K�\|N&�K9������e��\]��! \|��y�\]�6N�:�cGQ��L�����t���I�H����5�Ԕp'�%I!P��\`�S�f���мyslڴI��ZP�6}�\[��8q$�GSжm\[�Ԁ�E��kw�pw���B���'wsN�hӦ\

��IP����g���G�V-����5�
L��z���Q�l�,9JT������\`��c��~�6@�����oѣ��Z�\_! ��ȕ@�4�bne�� {VB\\�H4�(�y������g�����
�v�f�\*h~Q}��,o3��8�s���V�������:���\\��7�V��µO���1\]��Ku~V���Z�"�N��䩏�)�o�w�A\|���xp�\\DU����k��-\*x���:�����j��?po�� V\|K�ɑ���Q�\\�P\\5�'~�e�\\����i�Y�b��w�.��e������U�\[p�ػ��\_��o1���fݟ�螺9dXֵ�D� ! �����J'#E�U�����ߠ~M4P��K�!n���U9����ZWx�ѷ-�Z'��mQ�&?S�JKa��\`�E��g,2�o��k�z�k��ô�\_ԣ�\[��}w�5�.r��쓹=~:F��W\

�\_��Ҿ}�UMƌ���L��ں�Y��w#�\[.--e�d��:q2N�����s�D��琺����9+M��T89�ߞ�����븳?�2T��?}朚��L�iڡ�Ǒ�����j9��O���G�����ѭ��S�YfÆ\
hժ��$a!P(\[�nEA�U�jP�����\[��6\

! ��@@pN'���p���G�P���(��ç�<��t�u���� ! �@ �\
81����3�UUF�^8ƼV剸DU��Z�R�B�� ��V~C)'::{��ABR"d��ǫ�o ��ū/�5���Q���:Ζ!! ���8���=�eʔA��u�K�g�C3�3#\_�w��P:�Ѻ3u��}�� !  _�VV�8$���+߬=�2��q���-��˧g�BR�g���,8}����M�����/���/��g��\`�4:����'2)��d bbbP�F_\
_�R���m��$$''��\_����#@��4ʦ\*zJ��E�z����8\_��N��^�f! �@��/���G�d��_\

_8���;6ޜ�8��t??6�m�L}P��v�sG9����@# �&��xQ��ր�� 2�������t�?p<���g��o\|^b�pܓ}_\
_xN0ln���X���{��#߼�m\]j�I��<��4��k\\\������W.�{U�ze���א�DDD�\[ң��_\

_3���+.�+@�K�<L�,9�8��j��s+㘧�g+�%?���x�ݏ���Ū��ܜ����Mp�%c���e+1h�8��?gK˒�2V�۵����\[��{�ɹ�~��Q�_\

_ٓ����Y��\*��Ǟ\| OΙ���OFT�Jx���p��Q\|��j�^�(c�D,fN�'c�T��R�����c�\[�1d�$$&&+�<��Nc�Mw��UF��D�o���͚��o�F�UQ�V5�Q�^�;a���X��_\

_��gXHC}�������;),������j+w��m�mD�۷�\`V�6t���7��o�m2Ӹ�-��16�x" ��h�_\

_�o������a,�����T�T�^��m�֝4�yV�i�ؾ��Ɓ@\*�9mݶ��M\|�_\

_Z�y/1�5؀�@� �\_��y�7�.n�\]�\]��s�-���3_\
_��@@@���Bo�cLY�ou�!   ��@<\\\q�±��8A07��_\

---

