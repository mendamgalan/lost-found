# Оллоо — UI handoff

[Figma файл](https://www.figma.com/design/uyfC70n0tp5iMqeJPYglmS?node-id=4-2670)

Figma нь flattened screenshot биш: 10 дэлгэцийг засварлах текст, вектор болон 108 component instance-ээр байгуулсан. AppColors болон Layout variable collections, Material 3 товч/форм/навигаци, локал ItemCard, StatusPill, Category tile, InfoBanner компоненттой. Roboto нь Android дээрх Flutter-ийн үндсэн бичгийн хэвтэй нийцнэ.

| Дэлгэц | Flutter хэрэгжилт |
| --- | --- |
| 01 Нэвтрэх | `lib/auth/auth_page.dart` |
| 02 Бүртгүүлэх | AuthPage-ийн бүртгүүлэх төлөв |
| 03 Нууц үг сэргээх | AuthPage-ийн inline үйлдэл ба SnackBar; тусдаа route биш |
| 04 Нүүр / Хайх | `lib/items/items_page.dart` |
| 05 Шүүлтүүр | ItemsPage bottom sheet ба үр дүнгийн төлөв |
| 06 Дэлгэрэнгүй | `lib/items/item_detail_page.dart` |
| 07 Зар нийтлэх | `lib/items/create_item_page.dart` |
| 08 Миний зарууд | ItemsPage(ownerId: uid) |
| 09 Профайл | `lib/profile/profile_page.dart` |
| 10 Системийн төлөвүүд | StateMessage, InfoBanner болон SnackBar |

Figma дахь зар, хүний нэр, утас нь зөвхөн жишээ. Апп бодит Firebase өгөгдлийг ашиглана. Профайлын Figma талбарууд read-only мэдээллийг дүрсэлсэн; кодод profile edit нэмэгдсэн. Дэлгэцүүд нь урт агуулгын layout-ийг харуулах scroll content хэмжээсээр өгөгдсөн, бүх утас ижил өндөртэй гэж үзээгүй. Figma нь native editable design board; route-уудын clickable prototype холбоос нэмээгүй.

| Token | Утга | Хэрэглээ |
| --- | --- | --- |
| teal | `#006D66` | Үндсэн товч, hero, action |
| ink | `#172D31` | Гарчиг, үндсэн текст |
| canvas | `#F7F8F5` | Дэвсгэр |
| mint | `#E2F0EA` | Олсон, мэдээллийн banner |
| coral | `#AF452F` | Гээсэн төлөв |
| peach | `#FFEDE5` | Гээсэн зүйлийн дүрслэл |
| muted | `#5D7070` | Туслах текст |
| line | `#DFE6E1` | Хүрээ, тусгаарлагч |

Flutter-д content max width 720; зарын жагсаалт 1040. Жагсаалт боломжит өргөнөөс хамааран 1/2/3 баганатай. Картын өндөр агуулгаасаа хамаардаг; системийн том font дээр тогтмол өндөрт шахахгүй. Гол товч 54, input/card radius 16/22, хажуугийн үндсэн зай 20.

Одоогийн код нь server search/cursor, зураг, claim, handover, dispute, notification/admin flows болон profile edit-тай. Figma-ийн анхны 10 дэлгэцийг шинэ flows-той бүрэн синк хийгээгүй: Starter quota-д хүрсэн. Шинэ UI-ийн Flutter preview нь previews/ хавтсанд бий.

`icons/` дахь SVG-үүд Google Material Design Icons эх үүсвэртэй; хамт буй Apache 2.0 LICENSE-ийг хадгална. Эдгээр нь Figma-ийн вектор компонентын эх. Flutter нь өөрийн Material Icons font-ыг ашигладаг.
