# 🚀 Física de Movimento: O Conceito de Inércia Espacial

Este documento descreve os princípios matemáticos e físicos utilizados para implementar o movimento do jogador, baseando-se no modelo de impulso e vetores (semelhante ao jogo clássico Asteroids).

## 1. Decomposição de Vetores (Trigonometria)

A orientação do jogador é definida por um ângulo ($\theta$) em radianos. Quando o comando de acelerar (up) é ativado, o jogador não se move apenas; ele recebe um impulso na direção em que está virado.

Para aplicar este impulso, decompomos a força nos eixos cartesianos $X$ e $Y$:

$v_x = v_x + \cos(\text{angle}) \times \frac{\text{force}}{\text{mass}}$

$v_y = v_y + \sin(\text{angle}) \times \frac{\text{force}}{\text{mass}}$

Esta separação permite que o jogador rode sobre si mesmo (angle) sem alterar a sua trajetória atual ($v_x, v_y$) até que uma nova força seja aplicada.

## 2. Inércia e Atualização de Posição

Ao contrário de um movimento linear simples, aqui a velocidade é acumulada. Em cada ciclo de atualização (update), a posição é alterada pela velocidade corrente:

$$x_{novo} = x_{atual} + v_x$$

$$y_{novo} = y_{atual} + v_y$$

Como não existe atrito (drag) no código, a única forma de parar ou mudar de direção é aplicar uma força contrária.

## 3. Limitação de Velocidade (Magnitude)

Para evitar que a aceleração cresça indefinidamente, calculamos a velocidade escalar (magnitude do vetor) usando o Teorema de Pitágoras:

$$\text{Velocidade} = \sqrt{v_x^2 + v_y^2}$$

Se a velocidade ultrapassar o limite maxVelocity (atualmente $3.0f$), o vetor é normalizado:
 - Divide-se $v_x$ e $v_y$ pela velocidade atual (criando um vetor unitário de direção).
 - Multiplica-se o resultado pelo valor máximo permitido.

## 4. Rotação e Torque

A rotação segue uma lógica análoga à translação, mas aplicada ao ângulo:

**Torque**: A força de rotação definida como $0.2f$.

**Massa**: Quanto maior a massa do jogador, mais lenta será a sua resposta de rotação, simulando inércia rotacional ($\frac{\text{torque}}{\text{mass}}$).

**Limite Angular**: A maxAngularVelocity ($0.05f$) garante que o jogador não rode de forma descontrolada.


## 5. Relação com a Massa

A massa tem um papel central na física do jogo:
   
**Aceleração**: $a = \frac{F}{m}$. 

Um jogador com mais massa acelera mais devagar.

**Tamanho**: O raio visual é a raiz quadrada da massa ($r = \sqrt{mass}$), o que equilibra o crescimento visual com o peso físico.


Este modelo físico permite manobras complexas, como deslizar lateralmente enquanto se dispara para uma direção diferente.