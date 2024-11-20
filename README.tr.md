
# Introduction

Vania, Dart kullanarak yüksek performanslı web uygulamaları oluşturmak için tasarlanmış sağlam bir backend çerçevesidir. Basit yaklaşımı ve güçlü özellikleriyle Vania, hem yeni başlayanlar hem de deneyimli geliştiriciler için geliştirme sürecini kolaylaştırır.

## Features

✅ ***Ölçeklenebilirlik***: Yüksek trafikle başa çıkmak için tasarlanan Vania, uygulamanızın büyümesiyle birlikte zahmetsizce kendini ölçekler.

✅ ***Geliştici Dostu***: Web uygulaması geliştirmeyi çocuk oyuncağı haline getiren bir API ve açık kaynağın keyfini çıkarın.

✅ ***Kolay Rota Oluşturma***: Vania'nın verimli yönlendirme sistemi ile rotaları zahmetsizce tanımlayın ve yönetin, sağlam bir uygulama mimarisi elde edin.

✅ ***ORM Desteği***: Vania'nın güçlü ORM sistemini kullanarak veritabanlarıyla sorunsuz bir şekilde etkileşim kurun ve veri yönetimini basitleştirin.

✅ ***İstek Verisi Doğrulama***: Veri bütünlüğünü korumak ve güvenliği artırmak için gelen talep verilerini kolayca doğrulayarak kontrol altında tutun.

✅ ***Veritabanı Yönetimi***: Vania'nın yerleşik veritabanı taşıma desteğini kullanarak şema değişikliklerini kolaylıkla yönetin ve uygulayın.

✅ ***WebSocket***: WebSocket desteği ile sunucu ve istemciler arasında gerçek zamanlı iletişim sağlayarak kullanıcı deneyimini geliştirin.

✅ ***Komut Satırı Arayüzü (CLI)***: Vania'nın veritabanı oluşturma, model oluşturma ve daha fazlası için komutlar sunan basit CLI'si ile geliştirme işlemlerini kolaylaştırın.

Bir sonraki web uygulaması projeniz için Vania'nın basitliğini ve gücünü deneyimleyin

Dokümantasyona buradan göz atın: [Vania Dart Dokümantasyonu](https://vdart.dev)

# Hızlı Başlangıç 🚀

[Dart SDK](https://dart.dev) 'in makinenizde kurulu olduğundan emin olun.

YouTube Video [Hızlı Başlangıç](https://www.youtube.com/watch?v=5LiDQlqhNto)

[![Quick Start](http://img.youtube.com/vi/5LiDQlqhNto/0.jpg)](https://www.youtube.com/watch?v=5LiDQlqhNto "Hızlı Başlangıç")

## Kurulum 🧑‍💻

```shell
# 📦 pub.dev adresinden Vania CLI kurulumunu gerçekleştirin
dart pub global activate vania_cli
```

## Proje Oluşturma ✨

Oluşturmak için `vaniaFramework create` komutunu kullanın.

```shell
# 🚀 "blog" isminde yeni bir proje oluşturun
vaniaFramework create blog
```

## Geliştirme Sunucusunu Başlatın 🏁

Yeni oluşturulan projeyi açın ve geliştirme sunucusunu başlatın.

```shell
# 🏁 Sunucuyu başlat
vaniaFramework serve
```

Sanal Makine (VM) hizmetini etkinleştirmek için `--vm` bayrağını da ekleyebilirsiniz.

## Projeyi Derleyin 📦

Hazırladığınız projeyi derleyin

```shell
# 📦 Projeyi derleyin
vaniaFramework build
```

Proje kullanımı için, herhangi bir yere dağıtmak üzere sağlanan `Dockerfile` ve `docker-compose.yml` dosyalarını kullanarak dağıtın.

Örnek CRUD API Projesi [Github](https://github.com/vaniaFramework-dart/example)
