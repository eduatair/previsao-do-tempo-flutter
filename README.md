# Previsão do Tempo

Aplicativo desenvolvido em Flutter para consultar a previsão do tempo de cidades, consumindo serviços da API Open-Meteo.

## Funcionalidades

- Pesquisa de cidades pelo nome.
- Consulta das condições atuais.
- Exibição da previsão das próximas horas.
- Exibição da previsão para os próximos dias.
- Estados de carregamento, mensagens de erro e opção de tentar novamente.

## Tecnologias utilizadas

- Flutter e Dart
- Pacote `http` para requisições HTTP
- API [Open-Meteo Geocoding](https://geocoding-api.open-meteo.com/)
- API [Open-Meteo Forecast](https://api.open-meteo.com/)

## Como executar

1. Instale o [Flutter](https://docs.flutter.dev/get-started/install).
2. Clone este repositório:
   ```bash
   git clone URL_DO_SEU_REPOSITORIO
   ```
3. Entre na pasta do projeto:
   ```bash
   cd previsao_do_tempo_flutter
   ```
4. Instale as dependências:
   ```bash
   flutter pub get
   ```
5. Execute o aplicativo:
   ```bash
   flutter run
   ```

## Estrutura

```text
previsao_do_tempo_flutter/
├── lib/
│   └── main.dart
├── pubspec.yaml
├── .gitignore
└── README.md
```

## API

O aplicativo utiliza os serviços públicos da Open-Meteo para localizar cidades e obter dados meteorológicos. Consulte a documentação oficial em https://open-meteo.com/.

## Autor

Desenvolvido como atividade acadêmica do curso de Sistemas de Informação.
