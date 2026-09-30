import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/models.dart';

class StatementExportService {
  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _money(double n) => n.toStringAsFixed(2);
  String _clean(String v) => v.trim().isEmpty ? '—' : v.trim();

  // شعار التطبيق الأصلي المضمّن لتجنب تشويه الشعار أو الاعتماد على مسار ملف خارجي.
  static const _logoB64 = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCAEAAQADASIAAhEBAxEB/8QAGwABAAIDAQEAAAAAAAAAAAAAAAQFAgMGAQf/xAAZAQEAAwEBAAAAAAAAAAAAAAAAAgMEAQX/2gAMAwEAAhADEAAAAeMGnMAAAAAAAAAAAAAAAAAAAAAAAAAb9HOB3oAAAAAAAAAl85EzuZNOam22iFVd5ZORqdN47LXW2qMObSouv0Q70AAAAAABu3W9VGiTprqc1rFqPLb7DXCTtl5Qne2VlR21GXf5AjRhaUbXfqCy4AAAAABM1W9VGyvi6OReF2kAA92GrKRa95SZdjaxl86fTqY4bDalHU36HQ4AAAe+TORmVmWEYYey7iyzn/e5soT+aPqrj5Vj9LoJc5zrejs4TiS49LRr6JzFtGdjr2+WZvjHTRKrXlueYlw49AAAA9kx/Oc83+bO8+o2sSXn1K3Xy9eLoLHmqdD6Jo9Xbt+3RujLmIW6yye3WYy63lncFXs8DhqaRv2ZM6S4p67AcAAASot3CrOvsaaun6be8Z2j0uU8sOLp83vOR31Mp9pYerNuUiLJSoqLu4uf0uMvLTTyyz4nq/mO3xofSc5e2V81gcAAAALqlsa6Z9PdVFVPQ/RPk31mz0fKrKmpqkXHM6VXY48j0U75EiPI7bRweg9z+nTWGicU/DWtF6PidDS9Ny9dsbHdp7EOxAAASoufI39bYw8uKH9h+N/UtHpTdeNLRXbRtczsaudJ3Sn5IiS+3c7P21Wf1ryVS29mL4/M1d7qw8fjot8+7mNXvmjCDgAAAF35pkZMFT33DdHp39/zvRw6J8zj2Pvao2eeuWjRKjb+8xkeQoW2OvlqeVfY1nHapJW205PN6UYbfHAAAAAmWVLdZ8lbtzg2XfWs/kfrR9LgcR6512fEapPqeXyzY7c0GPnY5vLqNsPpcq/D7UWi983eKE6QAAAAE+AjG61V+dVMzTE39txwv59Xq0MLrKnl1CvpVubm7S8yo2ad2qjr0z+d883eGFmcAAAAAAABngd6Wfxl3i9m3VFPG3rseTwnR0tdVLcmeBfjBwAAAAAAAAAADLEdBwAAAAAAAAAAAAAAAAAAAAAAD//EACoQAAEEAQMDAwQDAQAAAAAAAAMAAQIEBRESExAhMBQxQBUgIjIjJGAz/9oACAEBAAEFAv8AaMKTw+Q0ZSTVyOvSuvSsvSp6slwE1i22JxbfjQrykoAhHxGFxv8ACgORHGGMOjyaKlZgye069SReoIvUkTWvskzSacdsvgCDvTMzNMkYKdmTp3d/uDpyOWEU9pk9ibp5yf4IRb12ZiWPFo62rYtGWjJ208wx8kneI4kK5PC0U0e48ZbMh4KajhazJsVTZX8SMYZKMdzyizeSOgRzm85LR1sW1bWW1lsW1DFIkq2DQawQN9k23QeD648VLgvUGFHxAj3JPfJmUYPJxYm2RDwUVHD1Ir6dUZfT6iJiakkXCyaVSoKoNFLEUZWSSTWCMq9li9bQ+K0R1zk4fFN9selCrGtW6FujG/1JkKwM7KSbpaJuPqoiLJM7jI3srZea1N+9utCvX8LPo6iOUk7aKtPkrK8ZxwZ+96uwFAkhEGRiidR9kXsX1gRtLIEdbpEmzdsgbgqO+jUQ89vIm5bfiAPkmT2n74ie7HrIv/YAKrINggIitmGYmO19C6h7K7Xd36UqjtJZc285H70/6uOl7+Ku2giLXvgSfgsiByD1RLcZ0BCmYo4MITqHWdcRH2VwKd4MVzw9OUjzmODmLlSNBvHXfUU/aXYmFntu9D44JnbEQ1FXFXjqydQ/Z5NCE8i63WjpqBpKOPhplSMGvN+2KF/IcnqLTto/iqv3f2N+9GfHeVm7GvKWUK657hU9a6RfTbLqsKQa8f3dmlGNYAlK0GCnkVVPM0L5+e3Lu5v6eLrx3HL/ANfFXfQqM3Zn0Q5bxlriM+2sBSv14p8kNSyjqrZ9TBv2XprBJxoRUawYJ+0Zvo9AXNayhHlZoj7EfUnii+kkRuze2MnyY+3AswtjzTTYuLJqNdl6UCaMYs/uyNbiKT3DkesOxzT7RDXnbNXqRBC9Llv6cFfyDfUc1p3wRNa8nZozyie9ZIuO6RCaUQupJk9cU5tFo9H7odYYVfyEAjqC1lenoPyV3/CSl2JhCaW1GoCK0Zvsko/qjXK9dFzomU83Zki3bRmrg5X7RicnKXyV3/N/YqrmetYBcBYhOyEallacVLN12T50ajmgOh2QGJZHWBZyp7C176rV1XrOZ4xaEbh/NB9s1NtW0dlotq2rsyebLVNLRyEmTqzPJwUl7KxYYTO+r+YRez9XkzJyumjKbwpTdGHxE6RhKaHRk6GKAmVi0w07vJ/gMSTLlknk7oIXNKFMcUzNHpOlvm1CKjVFFMzMtVMkYMa48vjRk8ZAssX7XnFlK0KKndk6lJ5P8gFrVXZ6Nvmt8vnO7v/ALL/xAAtEQACAgEDAgUDAwUAAAAAAAABAgADEQQSISAxBRATIlEwMkEUQmEkM0BQof/aAAgBAwEBPwH/ACgQfplgveNqR+IdQ89d/mDUPEsKnMVgwyPo23beBAj2cxdMv5gqQfiemnxLqwDhRBQ5lVZT8/Qtsx7V7yujHLdPftNjQoceQOeljtGYiY9x7wZPabGnpmbTFT5lWnZ+0s0roM+WcHHURkwkdoJqNSVO1It9iNts8hMlFARcxBYc7xgQnEHJ6rn2rKBF7SxdlpYjMtf1OFgGBiCUa3Yu1xLNTZau2pZfke2L1XjKTTnnEr7S26ocNEsX9ixXY9xiL/MS5B/Zrlz6kLubiOdzZiLuYLGGDjpYZGJUcNK+8sYq3tTM/qD8CItg+4wRf1Ng44EvBDYLZirNDXl957CE5Oephh5WeZYLD9hn6cn7m8hC7EcmFhEBc7Vl+NNp/THc9d492ZW3E9SepNxm6ZlVL2nCyqmvSpuMvuNz7j1soYYM9JhK6CxwJV4Y37uJqNAAgFQ5i+HXHvxK/DUX7+ZZdVpxj/k1Gpa48/S7TSa7d7LJfr1qfZiHxT4WWa+5/wCJ3/03/8QAKBEAAgECBAYCAwEAAAAAAAAAAAECAxESICExBBMiMEFREEIyQFBh/9oACAECAQE/Af2r9ttLcdb0c2RzJHOkRm07id+zOpbYUZTFRXkwRMEfRUhroKlIhDD2KkvCIUveXbcxxFOOduyIR8sem5jicxGJMlU9Ep2FNP4tdXzWE0MchN+RDN3qO3gSvoPRZqkrRKJLc8/CGSpX1QoKOrKC+xLNVXSUXqVNy6ExEhxf2ZFQuRWGNiTsri2ytXRDRlTb5Qy0URJSK8unD7zy0kPWORlhQY+lXkU71KmLPVWtynLSxgRaIoowlic4w3JTlVlYpwUFbPKNzlswJK8h8RFfiinX16mPiYEuJk9iMJVGU6agu3VoW1iQ4dyjcXC/6RoQX8f/xAA4EAABAgMECAMHBAIDAAAAAAABAAIDESEQEiIxIDAyQVFhcZETQIEEIzNCUmKxNGBygkOSU6Gi/9oACAEBAAY/Av3pe3eZoFwW0tpbSoQskArzcvLVoFlPrquXk6LibKlUqqNW5Zrcqt0JFEeRmdlSCqVhoq6QmtpUC4KpPkZnZXJSZ387yXJctTVSAmVSFdH3UXvIwH8QsV93qvg9ynRYExdqW6+qmdSGQ2lzjwV72h39WqUOGG6JbxEkW7wVL2gjxCd9JIxYTps4HV3juXKyTGknkploYPuK95GP9Qqsc7q5fp2L9OxUYW9CvdRAR9yusFd7uNkys5dFtlXTR1sUfcbDCvYTu1fhj1taAMRE3G2W0eSrDPdYD6aJ4CllIbkDkWm2I7dOlkD/AJXbWqnZPcpKG/i0WBrc3WNukyPFB7DUJsQbxoOB4rBDWFoCrVzipJ5G0cIsaNwqU7g3CNXXIWsH0zFg/ir8WJXhNNiRBebupNAwmXRJN6nQ8VgnxFvixBL6RYIQyZ+bIntB2nbOs62FRofMGwPZtN/FjF03hvQhszKaxuTRLRm5gmp4Gqk3dEY3yymnPdmaprBm4qH7MzJonrOlt36m23pXXcQqxXdlKG2SzFhRccgsDZdVS+eixFoWJxKZ7Oyk/xY6Mcm0Tn/AFORGrcLAVBd91l26XOWFrWqhf6BVD/Vy+X/AGQY4zNhByKndHUran0WBndEuGSe7cKCwQ/ncmp3XVi0OTXcRNAvbMhZQ2ran0CpDcVSEO6JuykbTe7krG/sqMHrYU2YwtqVc3NCc/0TuurBsNkI8BJShZzWItCxRCei2SepXwm9lJoAHK0tDZkKTafxCvvvXeZR6K4z1PBBjBT8qJd4yC6DWiwqIz6XTRJyCwQ+6w/+Qv8AJ3TQ8zdKuhfc2qoALSITA0GtEYUIgxTw+VeKfRBnHWkWFOZ9TbKQwqU0RZ7yK0Hgvdw3O60WBrG+k1jjOlX2X27yuACLt27WysBTIo+Uq8yIOhzWOKweq+LPoFRkQr4Dv9liY9v8A2vdRA7lvV+IZD8ohh8OHy0JmjVdbkvDb664GySro5WTBkVN7y7qbZATV6L2skNpT1912jRUBKxG6i2c7cIJWMyWEWSbVymc/I52ZqU5KuJUErC4xM+Sq8rZn1VLJuMlJlBx8tMZqRo7RqQs59FgElMmfmbsTPimtHVbR7raPnq/vL//EACoQAAIBAgUEAgEFAQAAAAAAAAABESExEEFRYXEwgaGxQJHBIGDR4fDx/9oACAEBAAE/If3ozqqPk3zfCLolyYs5eyN79D0+IjdDRD7iUNkiVFVdafGqfdF2l1EJKFToNJpp1TGSq+3w4gtM2VGNx4KpUuTNHAyQuWPadjb/AEJWrsPmPrZOLSiUypsx8F72fYjRCE+doig0fIxlm3v+pHmpJVqX5OwrffJbI4FzXf4M7LeSckkLoG23Lcvop1kTEmbGrIWgZa3WdDkuyu6JZDKtNHR1UEqN6CqyKbNRw9HESF/c0fRkx8gotqVEprYahxyuURT00pcK4mtZ7s+tC0wTsiWbRHVnIcw0yZyRYAgkqUFD/wBVZyNSVfsp+hbqzgugrD6JzX0cHI/mq9xLVPPpolaD5slkT3F7SJJZC6lfiIFdtB7PPBCt+4pG+/YQicnvipO3VUNfyVgnvXwZzXZalsj0FXXcqNYYctcUQV3LgpxqQTUycsunG5GDIVojZlvBjMspyEbsNg8udq7XQ8FuDOKhysXmdoNrqDSj1GyMdDgiRi8EDdXSiNA3Ll3EkFGpnJIjrPeMHlRnaIQ1TpLGcwn7EcDyFp2aNMLyojUxONTPMZJI8odS8vYES6FBKr2rwmW1P16KFc+Iv56fdEyhErCXG7zy4MU1oQIiKnWjAn/n9Qh60HlJedjicejjqXsbkaFWkXPeE5KEvkWBFGy/ReRp6daXm04JV9SZjJHvTBdU3UsxWy2stlBTk+BamTEGB6NbiwkhalQVmZq3U9IhSrpeoZ1VbGT2CgpOLwupGLVAshZVqT+V6+q4ssjr5vYuWWiRFw1d5vuNV1cssGoFsclj6ce5ybUnsRXORcsUq/ahQoVtbP7LTUntvB75+BvBHFkbSOOn5ThJANHIp96CsKkgUwqQMY8oO8s7Z+EUJSXDkKfpbdLLYTwEByiGikF932JIUmiyOtDu4o0pQmrMaudbtoZjBJRMPl3IhknIkL3dPkVB2JOLGMi6qRvZQSXBAnuYkoic3uQ0hb2jI8sDh0KFw5/0Qoqj2oHl1rUIoEkkNaTzZehU/RNT0G7Kh4Eg1bp7WMmSZGw4rtWT2JgaiTiUVjkXLK1xSBb5oJFjbLaSBoTnA9NfZI+uCRkYxIVzuw0vRvR3LPshudjd21ZmT61CEP8A3HV9Sf7YFBWhIr/CaLCRLIve5Rngb+H5gRTmpviPQiBb33FULNlgqRp5i1gEkFYWhuxNeScTT/ZIQu/jqz6Bi0F5CNLvOiJTTUpjOZe9RKwiTZYMZYeIIpmmDl/RR9/oDGg7SEYksk4eBmfHvbDoFCH0dkHDqxtqRUEh9krxuSNUKe6shOx551Pzzs9JqRkvrDnv1BNmHYnYpDlEs20Q+baT1fLIVOWzakibNlSWrrwIqITIiTdV3/jrbIsuicYdAncW5Ck/6FtIVVLuZRCY5T6rNMapuVqg3OCw0zyRY/x3EkkJQkTMl7LQYxnLfXUkdwxE0NRg+vPAxZBFnOxXVJpdiEtLPFhDTZEe1LorkMj3zZIhcXpHl8td/BpKoG/T6Lkw5IsNStzbewshSbLBlQGkZkcIr9TuEMIktsEKKEv74TPxUZ8JmKlHo6k4SSWVcs1S0FLQurqyTJt/kJtOVcXF0ZNQ1ohvJhZtu3uTPzbgb5/eX//aAAwDAQACAAMAAAAQ/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD9/wD/AP8A/wD/AP8A/wD/AO3YFZh2/wD/AP8A/wD/AP8AkWyuM0Tv/wD/APeN/wD/AMvXLcfP/wD/APtQVO7ptRuwYu//AP8A8C5QJ5CRunUJb/8A/wD+ciMrSiahZtn/AP8A/wD7Lsq06spw1gvv/wD/AP5sU+K760AyrV//AP8A/wD0AgpsZM+FX/8A/wD/AP8A5LrdGWP793f/AP8A/wD/AP8AiHj80J0V/wD/AP8A/wD/AP8A/sFUiPc//wD/AP8A/wD/AP8A/wD/ANz/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/xAApEQEAAgEDAQcFAQEAAAAAAAABABEhMUFRIDBhcYGR0fAQQKGxweHx/9oACAEDAQE/EPurQHTsyrVQWDcXpifFUFrTPyPAGh2I71i9vVgtdzRoW2QjFrhUtLt2DchA3D0KEF0JbB2uDRbAyOm9jN1UWggmuJ3sTgmcoHYom4YcfReFcK26aRdCKaOYACpvu3YtyRRLPoNFh4fLmBVHN+u0KztL2MelHTVxLhY7MYwDpctFWa23lfwIsSssBomsZMp1fmD1mp4d4KL6rx4mZD0ywzVtB5f56xmq0ZZsmDseXPv+5gsO6r/r+Yjpig7oSx4PTd8pUR0iVW47z5n/AGIXeeH0obT0vdnnIbubjLHSb85ccuqzO+Wh5laAczdDAoqaoAEQ74LeBxyw/IG7/Oukc5cOSWrJG7qS6EKdZXnz2IhXO7/CPPKODsNBiDA+Zdo/LB3ZfnrLENst7fgjeB4n2jFr9CX1jgSz4hofN+yFVmsOi07PPj3xXlre5/vv+Q2hp3e+sVVuvaquX7n/xAAkEQEBAQACAgICAQUAAAAAAAABABEhMSBBUWEQMKFAUHGR8P/aAAgBAgEBPxD+qA9frE1RHSW6vvgO/wACEdP0nx7S2sTtsF6voRADI7Mm7v6FPnYDnm+AbOdkj9ynLNcJEcfHaZT5Gx2SXXN9MWbrhCue5zPwd9k778XSbMc2Srsw4QnIvwwRWWOb1mQPdnI8k2Lvsccmal2OEebZpNawL8CWvlovqwxHvPQweiat9JEKwc2XNT4y0PjsE8Y8G99RsEYyrnlspwZemwA7gYZ5DQu/O2RdIO8En1E0OC5J0f8AHngYDtIe7H3t8C6dwDqE1xYf6hI8wONm8M6RxcTtKtyIHXNxBy3n8tjjv5/UgmM/w/iJbzb5f4XKpv8AmAOD+zf/xAAqEAEAAgEDAwQCAwEBAQEAAAABABEhMUFRYXGBkaGxwTDREEDw4SBg8f/aAAgBAQABPxD/AO0IO2YvLWtH9lSoZpjf40j9J3GFWbehgbnmfQAbIKTRaoiENnRd5eZFi3fr+qFtEqws31viCj/hNIUQDgKlf+UuVAbAUjuSgqvlx0f6eiA1dCDFG6XwbSpSi9VSzA/RR7x/vwxGj2pyfRmoeaWgDe/7oWBqrLriVHEoTLMIQlUJ/RKEh69kBhPQJjBwzLLYDl1hSlbq5f8A553iKFNCa93jJ9pjOvqpfjLoz7/xiNf6C1yJpz47Rs2k7AR3Rmi9fEdKTVXX8INrXMN1CM1PE0az1YrU1Ll6nt+YhpycRBLQtBv0JXVW4P3z+AFaC2E57Y1hsQ0BTxLRJtB6OfaXLn2v1aIaWvIF8CAV3q35lkETQOrbImtSzyjoXWRSrW3LEpr8SEFpoJcmGpGvARImPAJrMuOuXENkQPVuxON9cF3mhancmrNUxMotF+iMqbZvydP0+sIU/Ww+6yzlvLP4IZ1oDuJHOqWeQ/EyS81sgBoveZowvFWgNHvFtX8WL4eF55imyYvugVdPEQmdHp6S7E8BrsthAp7nHraFCiaqL8FQ73h8mYsPcPhl/U0TV4bj+AQNW9bMU4xANUYefq7HSAMtFaUeqjyps4K86x60eHR9Y+Ia6ODyfqbSs3MTjcOTc8m9o2FXAvDY4On4gVA1YLXRbN3j+AaobaTAAQsour4NAgBoShEBwjoj1Zoe3or6VNrKZXfPuO4MXFg8wcTJ7ZX21fWLhk8GWL4B3aveVhbBWErUYJOgE7So4l27b9IHzrLNqGCPwGwrCUOm1LXrHX8ODLVZ3iMlptZ6XLEYtrDWBXqwHNLhFSBbGo6+ukQ+gC8C6xtcd2NFfuJ9dYjgbjyMxUG6zc8NzSkuPSaJQrdgc5g5hFlK8XvBno7Z/qLdgQtapqdLr0ExyB7BfgtgsmtURbZXS2Dy0Qk7R9K1PNvxhhe48EIPAYA0IFbHCTNFrvix7MvEAf8AoG5eua/ROMavMDukC1BhO4R6mcgtvDRpBZvStoaGOycKRYi5iqiZa2G/WUYgVWdusSHqDzfI26QaJnIop/jBXrMA6GWYNBza19qXxLDNpq8u7+OteQn2mARS5lsxlGmuxXwSo3UrSymtdTX1iskdFyVpgsJvbFBqy7by4CCdiI71q+XMNjKuFDslbx6qalZ71GAEaCfdmAN1Oz6sWQWmlONnreIqpa3lb/5NIDnpbl8GYttGLtT6C+fyc6p9pkpe2mUNpNVcoH3LwRLmpJiQFy6JTu50D5jIm95761hXpCQDYREsRsZRygYmKPYzghANtefQhny7H9ZKqy6qe1+4e5YUP7hwiabon38IeHX4Qj9WVoItePlHRaYvF6PQJdm96H8dSNwHxDblF7lekttoJdMnzAeE1E4wAdLY4tWl24HiNlT1CL2k5+wyoLd6KnUWux0LsShdYEK4jRGF4pm3DzGOC4D10gLD/hwRF8IaBX1LA3tIvy2xSltYDmWYyOa6/pMRaq7XsTpF8346dsWHaJctZlrgoXqZ+oLCxzzYMCClDaNcNayoCTf7GZoINkf+Q196gIUQ6n0RMG9WKy8MdnlqXjEvxsu6kXscQx2Pp66wYrGxf3iUQGgKNIygv5mKdV4mMZD3ahNFavIX4jUOFPlfqUfuvf8AH0b2UAmjmdXouo9pdFld5p8VCTShuXEPeGFp1s9qVabgB73LgsOV8RvQ9bfMFFDYQS18CUZyheUPFyk5bAj1MzIWlbuki/nCPdDJ0GI1Wr9G8cgHPfLqfEKmoijN0PlLc1TW80/cSi6rf5Lrc4PjEGe8Tk01lCB/lqRX6S3AFsQtVbfXIustte+uZasJzbH5IMo8vu+7eaIcXxMB5I1oJktLlIFMtiPiGCEUIER3JXlajl6r/iOvEwKjKejQjo2TR35gXGsTo/7+XMufbZZfiBwr/P8AiW+5SHK38LECwKRMJGLabxw7XOgGCPiXj+L2gtE1HRHeIugX/JswVSGjjeMsXC7RQPLGG/HtykY7jh7H2ymDQmwI2eyo4Gn5bO098mYRa7F2hC5A2rsJ5GIIKWKnhUDWk2velw1C82+pjr35D7sU0g5f0w4DOoAPRuORUt94WZmTiMviG7FALGIX+cEUTKyt693WL2TtccZq7wZS3O/o/aHpPQIPGAOh+Zw1k7bwQEbEsgb+0eJkoVpsY32XMpdvT9pSZXlmW78TJO8CoprT4jcrtATskAk9JmHBxE7DQ4/jQiEFrKXYZC/L6gUwKAKCMQB/cYiJVq7v56wFYb4Z9ynAllcRdqG2UKoDy5ZZzeFyv4cf/hKz2uinJo/yVatroh3d/wChK1E6vPcY0iR8HU7+vSPpbaOv9EO30OSCVZ6karOm0MdkVya6EGAPzr0ECku1B/GR4lw94RvpwEa8k/hOlOhRGG/XBy9iURVwrX+opKqrqv8AVde2wRaB67Os/URLzHD+JNm9EhrVbYv3hz/og2ItXd1f9gEiBsTaEmaK6d3WMtQq1YMEC0HynuIOKVqr1/uqiqFCro/+y//Z';

  pw.Widget _dir(String text, pw.TextDirection direction, pw.TextStyle style) =>
      pw.Directionality(textDirection: direction, child: pw.Text(text, style: style, maxLines: 3));

  Future<pw.Font> _arabicFont() => PdfGoogleFonts.notoNaskhArabicRegular();
  Future<pw.Font> _arabicBoldFont() => PdfGoogleFonts.notoNaskhArabicBold();

  Future<Uint8List> buildPdf(Account account, List<TransactionItem> items, double ignoredBalance, {Map<String, String>? profile}) async {
    final p = profile ?? const <String, String>{};
    final base = (p['base_currency'] ?? '').trim().isEmpty ? (items.isNotEmpty ? items.first.baseCurrency : account.currency) : p['base_currency']!.trim();
    final ordered = [...items]..sort((a,b)=>a.date.compareTo(b.date));
    double credit = 0, debit = 0, running = 0;
    for (final x in ordered) {
      final v = x.baseAmount.abs();
      if (x.type == 'credit') { credit += v; running += v; }
      else if (x.type == 'debit') { debit += v; running -= v; }
    }
    final net = credit - debit;
    final status = net > 0 ? 'له' : net < 0 ? 'عليه' : 'متوازن';
    final ar = _clean(p['user_name'] ?? 'سمير الحسامي');
    final en = _clean(p['user_name_en'] ?? 'Sameer Alhosami');
    final phone = _clean(p['phone'] ?? '');
    final arAddress = _clean(p['address_ar'] ?? '');
    final enAddress = _clean(p['address_en'] ?? '');
    final logo = pw.MemoryImage(base64Decode(_logoB64));
    final arFont = await _arabicFont();
    final boldFont = await _arabicBoldFont();
    final normal = pw.TextStyle(font: arFont, fontSize: 9.5);
    final bold = pw.TextStyle(font: boldFont, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final title = pw.TextStyle(font: boldFont, fontSize: 20, fontWeight: pw.FontWeight.bold);
    final small = pw.TextStyle(font: arFont, fontSize: 8);
    final generated = _date(DateTime.now());

    pw.Widget arText(String s, {double size=9.5, bool isBold=false, pw.Alignment align=pw.Alignment.centerRight}) =>
        pw.Align(alignment: align, child: pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Text(s, style: pw.TextStyle(font:isBold?boldFont:arFont,fontSize:size,fontWeight:isBold?pw.FontWeight.bold:pw.FontWeight.normal))));
    pw.Widget enText(String s, {double size=9.5, bool isBold=false, pw.Alignment align=pw.Alignment.centerLeft}) =>
        pw.Align(alignment: align, child: pw.Directionality(textDirection: pw.TextDirection.ltr, child: pw.Text(s, style: pw.TextStyle(font:arFont,fontSize:size,fontWeight:isBold?pw.FontWeight.bold:pw.FontWeight.normal))));

    final rows = <List<String>>[];
    for (final x in ordered) {
      final value = x.baseAmount.abs();
      final signed = x.type == 'credit' ? value : x.type == 'debit' ? -value : 0;
      running = (rows.isEmpty ? 0 : running);
      rows.add([
        _date(x.date),
        _clean(x.note.isEmpty ? x.category : x.note),
        x.currency,
        '${_money(x.amount)}',
        x.type == 'credit' ? 'له' : x.type == 'debit' ? 'عليه' : 'دفع',
        '${_money((rows.fold<double>(0,(s,r)=>s + (r[4]=='له'?double.tryParse(r[3])??0:-(double.tryParse(r[3])??0)))) + signed.abs())} ${signed>=0?'له':'عليه'}'
      ]);
    }
    // Recalculate the displayed running balance from the actual base amounts, never from the table strings.
    double rowBalance = 0;
    for (var i=0;i<ordered.length;i++) {
      final x=ordered[i];
      rowBalance += x.type=='credit' ? x.baseAmount.abs() : x.type=='debit' ? -x.baseAmount.abs() : 0;
      rows[i][5]='${_money(rowBalance.abs())} ${rowBalance>0?'له':rowBalance<0?'عليه':'متوازن'}';
    }

    final header = pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 9),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700, width: 1.2))),
      child: pw.Row(textDirection: pw.TextDirection.ltr, crossAxisAlignment: pw.CrossAxisAlignment.center, children:[
        pw.Expanded(flex: 4, child: enText('$en\n$phone\n$enAddress', size:8.5)),
        pw.Expanded(flex: 2, child: pw.Center(child: pw.Image(logo, width: 58, height: 58, fit: pw.BoxFit.contain))),
        pw.Expanded(flex: 4, child: arText('$ar\n$phone\n$arAddress', size:8.5)),
      ]),
    );

    final info = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children:[
        arText('اسم العميل / المورد: ${_clean(account.name)}', isBold:true),
        arText('الهاتف: ${_clean(account.phone)}'),
        arText('العنوان: ${_clean(account.address)}'),
        arText('الملاحظات: ${_clean(account.notes)}'),
        arText('تاريخ إنشاء الكشف: $generated'),
      ]),
    );

    pw.Widget summaryCard(String label, String value) => pw.Expanded(child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 3),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey500), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(children:[arText(label,isBold:true,align:pw.Alignment.center), pw.SizedBox(height:3), arText(value, isBold:true, size:11, align:pw.Alignment.center)]),
    ));

    final tableData = rows.isEmpty ? <List<String>>[['—','لا توجد عمليات مسجلة','—','—','—','—']] : rows;
    final table = pw.TableHelper.fromTextArray(
      headers: const ['التاريخ','البيان','العملة','المبلغ','النوع','الرصيد'],
      data: tableData,
      headerCount: 1,
      border: pw.TableBorder.all(color: PdfColors.grey500, width: .55),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(font: boldFont, fontSize: 8.5),
      cellStyle: pw.TextStyle(font: arFont, fontSize: 8),
      columnWidths: const {0: pw.FlexColumnWidth(1.25),1: pw.FlexColumnWidth(2.25),2: pw.FlexColumnWidth(.8),3: pw.FlexColumnWidth(1.1),4: pw.FlexColumnWidth(.85),5: pw.FlexColumnWidth(1.25)},
    );

    final totals = pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children:[
        arText('إجمالي له: ${_money(credit)} $base', isBold:true),
        arText('إجمالي عليه: ${_money(debit)} $base', isBold:true),
        arText('الرصيد النهائي: ${_money(net.abs())} $base', isBold:true),
        arText('الحالة: $status', isBold:true),
      ]),
    );

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 30),
      textDirection: pw.TextDirection.rtl,
      header: (ctx) => header,
      footer: (ctx) => pw.Align(alignment: pw.Alignment.center, child: arText('صفحة ${ctx.pageNumber}', size:7, align:pw.Alignment.center)),
      build: (ctx) => [
        pw.SizedBox(height: 8),
        arText('كشف حساب', size:20, isBold:true, align:pw.Alignment.center),
        pw.SizedBox(height: 10),
        info,
        pw.SizedBox(height: 10),
        pw.Row(children:[
          summaryCard('إجمالي له','${_money(credit)} $base'),
          summaryCard('إجمالي عليه','${_money(debit)} $base'),
          summaryCard('الرصيد النهائي','${_money(net.abs())} $base — $status'),
        ]),
        pw.SizedBox(height: 14),
        arText('تفاصيل العمليات', size:13, isBold:true),
        pw.SizedBox(height: 6),
        table,
        totals,
      ],
    ));
    return pdf.save();
  }

  Future<void> share(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    final bytes = await buildPdf(account, items, balance, profile: profile);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/كشف_حساب_${account.id}.pdf');
    await file.writeAsBytes(bytes, flush:true);
    await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/pdf')],text:'كشف حساب ${account.name}'));
  }

  Future<void> printStatement(Account account, List<TransactionItem> items, double balance, {Map<String, String>? profile}) async {
    final bytes = await buildPdf(account, items, balance, profile: profile);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name:'كشف_حساب_${account.id}.pdf');
  }

  Future<void> shareWord(Account account, List<TransactionItem> items, double balance, Map<String, String> profile) async {
    final dir = await getTemporaryDirectory();
    final safe = account.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/كشف_حساب_$safe.doc');
    final ar = _clean(profile['user_name'] ?? 'سمير الحسامي');
    final html = '<html dir="rtl" lang="ar"><meta charset="utf-8"><body><h1 style="text-align:center">كشف حساب</h1><h2>${_clean(account.name)}</h2><p>الهاتف: ${_clean(account.phone)}<br>العنوان: ${_clean(account.address)}</p><p>الرصيد: ${_money(balance.abs())} ${balance>=0?'له':'عليه'}</p><p>صاحب الدفتر: $ar</p></body></html>';
    await file.writeAsString(html,encoding:utf8,flush:true);
    await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/msword')],text:'كشف حساب ${account.name}'));
  }
}
